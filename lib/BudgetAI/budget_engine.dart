import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:provider/provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../database/sqlite_management.dart';
import '../services/date_range.dart';

class BudgetEngine {
  BudgetEngine._();
  static final BudgetEngine instance = BudgetEngine._();

  Future<void> _ensureTables() async {
    final db = SqliteManager.instance.db;
    // Tabla para guardar como la persona interactua con el presupuesto generado por IA (aceptado / editado / rechazado)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_feedback_tb (
        id_category INTEGER PRIMARY KEY,
        accepted    INTEGER NOT NULL DEFAULT 0,
        edited      INTEGER NOT NULL DEFAULT 0,
        rejected    INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Preferencia aprendida
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_pref_tb (
        id_category INTEGER PRIMARY KEY,
        pref_budget REAL    NOT NULL,
        samples     INTEGER NOT NULL
      );
    ''');
  }

  // 1. Cargar el modelo TFLite
  Interpreter? _tflite;
  Future<void> _ensureModelLoaded() async {
    if (_tflite != null) return;

    _tflite = await Interpreter.fromAsset(
      'assets/AI_model/budget_adjuster.tflite',
    );
  }

  double _predictTFLite(double spent90, double plan) {
    final meanDaily = spent90 / 90.0;
    final input = [
      [spent90, meanDaily, plan],
    ];
    final output = List.filled(1, List.filled(1, 0.0));
    _tflite?.run(input, output);
    return output[0][0];
  }

  // 2. Mezclar predicción del modelo con preferencia del usuario
  Future<double> _blendWithUserPref(int idCat, double modelPred) async {
    final db = SqliteManager.instance.db;
    final rows = await db.query(
      'ai_pref_tb',
      columns: ['pref_budget', 'samples'],
      where: 'id_category = ?',
      whereArgs: [idCat],
      limit: 1,
    );
    if (rows.isEmpty) return modelPred; // sin historial

    final pref = rows.first['pref_budget'] as double;
    final n = rows.first['samples'] as int;

    // weight ↑ con el nº de muestras (hasta 0.8)
    final w = math.min(0.8, n / (n + 2));
    return modelPred * (1 - w) + pref * w;
  }

  //  3. Recalcular presupuesto para cada ítem
  static const _tol = 350.0;
  static double _round5(double x) => math.max(0, (x / 5).round() * 5);

  Future<List<ItemUi>> recalculate(double income, BuildContext ctx) async {
    await _ensureTables();
    await _ensureModelLoaded();

    final raw = await _fetchRaw(ctx);
    final List<_ItemAdjusted> adj = [];

    // Sugerencia de presupuesto para cada ítem
    for (final r in raw) {
      final diff = (r.spent90 - r.plan).abs();
      double sug = (diff <= _tol) ? r.plan : _predictTFLite(r.spent90, r.plan);
      sug = await _blendWithUserPref(r.idCat, sug); // mezcla
      sug = _round5(sug);

      // reglas gasto / ahorro
      if (r.type == 1) {
        if (r.spent90 < r.plan && sug >= r.plan) sug = _round5(r.spent90);
        if (r.spent90 > r.plan && sug <= r.plan)
          sug = _round5(math.max(r.spent90, r.plan + 5));
      } else if (r.type == 3) {
        if (r.spent90 > r.plan && sug <= r.plan)
          sug = _round5(math.max(r.spent90, r.plan + 5));
        if (r.spent90 < r.plan && sug >= r.plan)
          sug = _round5(math.max(r.spent90, r.plan * .8));
      }
      adj.add(_ItemAdjusted(raw: r, newBudget: sug));
    }

    // Tope global (que no supere los ingresos del usuario)
    double sobra = adj.fold(0.0, (s, e) => s + e.newBudget) - income;
    if (sobra > 0) _recorteGlobal(adj, sobra);

    return adj;
  }

  // 4. Persistencia de los cambios
  Future<void> persist(List<ItemUi> items, BuildContext ctx) async {
    final db = SqliteManager.instance.db;
    final int? idBudget = ctx.read<ActiveBudget>().idBudget;
    if (idBudget == null) return; // ①  sin presupuesto → nada que hacer

    await db.transaction((txn) async {
      for (final it in items) {
        /*─────────────────────────
        A) Ítem existente (UPDATE)
      ─────────────────────────*/
        if (it.idItem > 0) {
          await txn.update(
            'item_tb',
            {'amount': it.newPlan},
            where: '''
            id_item   = ?
            AND id_card IN (SELECT id_card
                              FROM card_tb
                             WHERE id_budget = ?)         -- ②  filtro por presupuesto
          ''',
            whereArgs: [it.idItem, idBudget],
          );
        }
        /*─────────────────────────
        B) Ítem nuevo (INSERT)
      ─────────────────────────*/
        else {
          // ③  Seguridad adicional: aseguramos que el card pertenezca al presupuesto
          final cardCheck = await txn.query(
            'card_tb',
            columns: ['id_card'],
            where: 'id_card = ? AND id_budget = ?',
            whereArgs: [it.idCard, idBudget],
            limit: 1,
          );
          if (cardCheck.isEmpty)
            continue; // card fuera de presupuesto → lo ignoramos

          await txn.insert('item_tb', {
            'id_card': it.idCard,
            'id_category': it.idCat,
            'amount': it.newPlan,
            'id_itemType': 2,
            'date_crea': DateTime.now().toIso8601String(),
          });
        }

        /*─────────────────────────
        C) Feedback y preferencia  (sin campo budget)
      ─────────────────────────*/
        final col = (it.newPlan == it.aiPlan) ? 'accepted' : 'edited';
        await txn.rawInsert(
          '''
        INSERT INTO ai_feedback_tb(id_category,$col)
        VALUES(?,1)
        ON CONFLICT(id_category) DO UPDATE SET $col = $col + 1;
        ''',
          [it.idCat],
        );

        await txn.rawInsert(
          '''
        INSERT INTO ai_pref_tb(id_category,pref_budget,samples)
        VALUES(?,?,1)
        ON CONFLICT(id_category) DO UPDATE
          SET samples     = samples + 1,
              pref_budget = (pref_budget * (samples) + ?) / (samples + 1);
        ''',
          [it.idCat, it.newPlan, it.newPlan],
        );
      }
    });

    /*─────────────────────────
    D) Sincronización Firebase
      (ya sabe cuál es el presupuesto, se lo pasamos)
  ─────────────────────────*/
    _syncWithFirebaseIncremental(ctx, items);
  }

  /* HELPERS INTERNOS */

  // Para sacar la data
  Future<List<_ItemRaw>> _fetchRaw(BuildContext ctx) async {
    final db = SqliteManager.instance.db;
    final bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
    if (bid == null) return [];

    // 1. rango
    final range = await periodRangeForBudget(bid);
    if (range == PeriodRange.empty) return [];

    final sIso = range.start.toIso8601String();
    final eIso = range.end.toIso8601String();

    // 2. items con transacciones
    final items = await db.rawQuery(
      '''
    SELECT DISTINCT it.id_item  idItem,
           it.id_card          idCard,
           it.id_category      idCat,
           it.amount           plan,
           it.id_itemType      type,
           ct.name             catName
    FROM item_tb it
    JOIN transaction_tb t ON t.id_category = it.id_category
    JOIN card_tb ca       ON ca.id_card = it.id_card
    JOIN category_tb   ct ON ct.id_category = it.id_category
    WHERE t.id_budget = ? AND ca.id_budget = ? AND t.date BETWEEN ? AND ?;
  ''',
      [bid, bid, sIso, eIso],
    );

    // 3. gasto por categoría (incluyendo huerfanas)
    final spentRows = await db.rawQuery(
      '''
    SELECT COALESCE(id_category,-1) idCat, SUM(amount) spent
    FROM   transaction_tb
    WHERE  id_budget = ? AND date BETWEEN ? AND ?
    GROUP  BY COALESCE(id_category,-1);
  ''',
      [bid, sIso, eIso],
    );

    final spent = {
      for (final r in spentRows)
        r['idCat'] as int: (r['spent'] as num).toDouble(),
    };

    // 4. lista con items del plan
    final list = <_ItemRaw>[
      for (final r in items)
        _ItemRaw(
          idItem: r['idItem'] as int,
          idCard: r['idCard'] as int,
          idCat: r['idCat'] as int,
          catName: r['catName'] as String,
          type: r['type'] as int,
          plan: (r['plan'] as num).toDouble(),
          spent90: spent[r['idCat']] ?? 0.0,
        ),
    ];

    // 5. transacciones sin plan  ->  “Otros” (provisional)
    const kOtrosCat = 7;
    final catsEnPlan = {for (final it in list) it.idCat};

    double extraOtros = 0.0;
    spent.forEach((cat, amt) {
      if (cat == kOtrosCat) return;
      if (!catsEnPlan.contains(cat)) extraOtros += amt;
    });

    final idxOtros = list.indexWhere((e) => e.idCat == kOtrosCat);

    if (idxOtros >= 0) {
      // Ya existe “Otros” -> solo acumulamos gasto extra
      list[idxOtros] = list[idxOtros].copyWith(
        spent90: list[idxOtros].spent90 + extraOtros,
      );
    } else if (extraOtros > 0 || spent.containsKey(kOtrosCat)) {
      // Generamos registro provisional (idItem = -1 marca que aún no existe)
      list.add(
        _ItemRaw(
          idItem: -1, // -1 → deja que SQLite auto-asigne con el auto-increment
          idCard: 2,
          idCat: kOtrosCat,
          catName: 'Otros',
          type: 1,
          plan: 0,
          spent90: (spent[kOtrosCat] ?? 0) + extraOtros,
        ),
      );
    }
    return list;
  }

  /// Recorte global de presupuesto generado por IA excede ingresos del usuario
  ///
  void _recorteGlobal(List<_ItemAdjusted> adj, double exceso) {
    // colchon
    final sup =
        adj.where((e) => e.newBudget > e.raw.spent90).toList()
          ..sort((a, b) => b.newBudget.compareTo(a.newBudget));

    for (final e in sup) {
      if (exceso <= 0) break;
      final min = math.max(e.raw.spent90, 5);
      final cut = math.min(e.newBudget - min, exceso);
      e.newBudget = _round5(e.newBudget - cut);
      exceso -= cut;
    }

    // prioridad
    if (exceso > 0) {
      adj.sort((a, b) => _prio(b).compareTo(_prio(a)));
      for (final e in adj) {
        if (exceso <= 0) break;
        final min =
            (e.raw.type == 3) ? 5.0 : math.max(e.raw.spent90 - _tol, 5.0);
        while (e.newBudget - 5 >= min && exceso > 0) {
          e.newBudget -= 5;
          exceso -= 5;
        }
        e.newBudget = _round5(e.newBudget);
      }
    }
  }

  // prioridad para recortes (3 = Ultimo, 1 = primero)
  int _prio(_ItemAdjusted e) {
    final inc = e.newBudget - e.raw.plan;
    if (e.raw.type == 1) {
      return inc > 0
          ? 3
          : inc == 0
          ? 2
          : 1; // gasto
    } else {
      return inc < 0
          ? 3
          : inc == 0
          ? 2
          : 1; // ahorro
    }
  }
}

// Modelos internos para SQLite y UI
class _ItemRaw {
  final int idItem, idCard, idCat, type;
  final String catName;
  final double plan, spent90;

  const _ItemRaw({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.catName,
    required this.type,
    required this.plan,
    required this.spent90,
  });

  _ItemRaw copyWith({
    int? idItem,
    int? idCard,
    int? idCat,
    String? catName,
    int? type,
    double? plan,
    double? spent90,
  }) {
    return _ItemRaw(
      idItem: idItem ?? this.idItem,
      idCard: idCard ?? this.idCard,
      idCat: idCat ?? this.idCat,
      catName: catName ?? this.catName,
      type: type ?? this.type,
      plan: plan ?? this.plan,
      spent90: spent90 ?? this.spent90,
    );
  }
}

class _ItemAdjusted extends ItemUi {
  final _ItemRaw raw;
  double newBudget;
  _ItemAdjusted({required this.raw, required this.newBudget})
    : super(
        idItem: raw.idItem,
        idCard: raw.idCard,
        idCat: raw.idCat,
        catName: raw.catName,
        oldPlan: raw.plan,
        spent: raw.spent90,
        aiPlan: newBudget,
        newPlan: newBudget,
      );
}

class ItemUi {
  final int idItem, idCard, idCat;
  final String catName;
  final double oldPlan, spent, aiPlan;
  double newPlan;
  ItemUi({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.catName,
    required this.oldPlan,
    required this.spent,
    required this.aiPlan,
    required this.newPlan,
  });
}

/// Sincroniza los cambios locales con Firebase Firestore
Future<void> _syncWithFirebaseIncremental(
  BuildContext ctx,
  List<ItemUi> items,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final int? bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
  if (bid == null) return;

  /* ────────────────────────────────────────────────────────────
     1.  PREPARAMOS LISTAS COMPLETAS DE LO QUE EXISTE LOCALMENTE
  ──────────────────────────────────────────────────────────── */
  final db = SqliteManager.instance.db;

  final localCardIds =
      (await db.rawQuery('SELECT id_card FROM card_tb WHERE id_budget = ?', [
        bid,
      ])).map((r) => (r['id_card'] as int).toString()).toSet();

  final localItemIds =
      (await db.rawQuery(
        '''
    SELECT it.id_item
    FROM   item_tb it
    JOIN   card_tb ca USING(id_card)
    WHERE  ca.id_budget = ?
    ''',
        [bid],
      )).map((r) => (r['id_item'] as int).toString()).toSet();

  /* ────────────────────────────────────────────────────────────
     2.  ARRANCAMOS SINCRONIZACIÓN
  ──────────────────────────────────────────────────────────── */
  final fs = FirebaseFirestore.instance;
  final userDoc = fs.collection('users').doc(user.uid);
  final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

  final secColl = budgetDoc.collection('sections');
  final itmColl = budgetDoc.collection('items');

  final remoteSecIds = (await secColl.get()).docs.map((d) => d.id).toSet();
  final remoteItmIds = (await itmColl.get()).docs.map((d) => d.id).toSet();

  /* ────────────────────────────────────────────────────────────
     3.  UPDATES / INSERTS
  ──────────────────────────────────────────────────────────── */
  WriteBatch batch = fs.batch();
  int op = 0;
  Future<void> commitIfNeeded() async {
    if (op >= 400) {
      await batch.commit();
      batch = fs.batch();
      op = 0;
    }
  }

  /* agrupamos ítems por tarjeta */
  final Map<int, List<ItemUi>> byCard = {};
  for (final it in items) {
    byCard.putIfAbsent(it.idCard, () => []).add(it);
  }

  /* necesitamos los títulos de las tarjetas */
  final titleRows = await db.rawQuery(
    'SELECT id_card, title FROM card_tb WHERE id_card IN (${byCard.keys.join(",")})',
  );
  final cardTitle = {
    for (final r in titleRows) r['id_card'] as int: r['title'] as String,
  };

  for (final entry in byCard.entries) {
    final idCard = entry.key;
    final secId = idCard.toString();
    final title = cardTitle[idCard] ?? 'Tarjeta $idCard';

    /* sección (upsert) */
    batch.set(secColl.doc(secId), {'title': title}, SetOptions(merge: true));
    op++;
    await commitIfNeeded();
    remoteSecIds.remove(secId); // marcada como existente

    /* ítems */
    for (final it in entry.value) {
      /* si el id venía como -1 ⇒ buscamos el real en SQLite */
      int realId = it.idItem;
      if (realId <= 0) {
        final row = await db.rawQuery(
          '''
          SELECT id_item FROM item_tb
          WHERE id_card = ? AND id_category = ?
          ORDER BY id_item DESC LIMIT 1
          ''',
          [it.idCard, it.idCat],
        );
        if (row.isNotEmpty) realId = row.first['id_item'] as int;
      }

      final itId = realId.toString();

      batch.set(itmColl.doc(itId), {
        'idCard': it.idCard,
        'idCategory': it.idCat,
        'idItemType': 2,
        'name': it.catName,
        'amount': it.newPlan,
      }, SetOptions(merge: true));

      op++;
      await commitIfNeeded();
      remoteItmIds.remove(itId); // existe / actualizado
    }
  }

  /* ────────────────────────────────────────────────────────────
     4.  BORRAR SOLO LO QUE YA NO EXISTE LOCALMENTE
  ──────────────────────────────────────────────────────────── */
  remoteSecIds.removeAll(localCardIds); // secciones huérfanas
  for (final sid in remoteSecIds) {
    batch.delete(secColl.doc(sid));
    op++;
    await commitIfNeeded();
  }

  remoteItmIds.removeAll(localItemIds); // ítems huérfanos
  for (final iid in remoteItmIds) {
    batch.delete(itmColl.doc(iid));
    op++;
    await commitIfNeeded();
  }

  if (op > 0) await batch.commit();
}
