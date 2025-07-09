import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pocketplanner/services/active_budget.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path/path.dart' as p;
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
    final dbDir = await getDatabasesPath();
    final file = File(p.join(dbDir, 'budget_adjuster.tflite'));
    if (!await file.exists()) {
      final bytes = await rootBundle.load(
        'assets/AI_model/budget_adjuster.tflite',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _tflite = await Interpreter.fromFile(file);
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
        if (r.spent90 > r.plan && sug <= r.plan) {
          final f = 0.23 + math.Random().nextDouble() * (0.35 - 0.23);
          final extra = (r.spent90 - r.plan) * f;
          sug = _round5(r.plan + extra);
        }
      } else if (r.type == 3) {
        if (r.spent90 > r.plan && sug <= r.plan)
          sug = _round5(math.max(r.spent90, r.plan + 5));
        if (r.spent90 < r.plan && sug >= r.plan)
          sug = _round5(math.max(r.spent90, r.plan * .8));
      }
      adj.add(_ItemAdjusted(raw: r, newBudget: sug));
    }

    // Tope global (que no supere los ingresos del usuario)
    _recorteGlobal(adj, ingreso: income);

    return adj;
  }

  // 4. Persistencia de los cambios
  Future<void> persist(List<ItemUi> items, BuildContext ctx) async {
    final db = SqliteManager.instance.db;

    await db.transaction((txn) async {
      for (final it in items) {
        // 1) UPDATE; si no existe, inserta nuevo
        final rows = await txn.update(
          'item_tb',
          {'amount': it.newPlan},
          where: 'id_item = ?',
          whereArgs: [it.idItem],
        );

        if (rows == 0) {
          await txn.insert('item_tb', {
            'id_item': it.idItem,
            'id_card': it.idCard,
            'id_category': it.idCat,
            'amount': it.newPlan,
            'id_itemType': 1,
            'date_crea': DateTime.now().toIso8601String(),
          });
        }

        // 2) feedback
        final col = (it.newPlan == it.aiPlan) ? 'accepted' : 'edited';
        await txn.rawInsert(
          '''
        INSERT INTO ai_feedback_tb(id_category,$col)
        VALUES(?,1)
        ON CONFLICT(id_category) DO UPDATE SET $col = $col + 1;
      ''',
          [it.idCat],
        );

        // 3) preferencia incremental
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

    // 5. Sincronización con Firebase
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
SELECT it.id_item            AS idItem,
       it.id_card            AS idCard,
       it.id_category        AS idCat,
       it.amount             AS plan,
       ct.id_movement        AS type,
       ct.name               AS catName
FROM   item_tb it
JOIN   card_tb ca        ON ca.id_card     = it.id_card
JOIN   category_tb ct    ON ct.id_category = it.id_category
WHERE  ca.id_budget = ? and ca.title != "Ingresos";                     -- ← solo este filtro
''',
      [bid],
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
      final otrosCard =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT id_card FROM card_tb '
              'WHERE id_budget = ? AND title = ? LIMIT 1',
              [bid, 'Gastos'],
            ),
          ) ??
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT id_card FROM card_tb '
              'WHERE id_budget = ? ORDER BY id_card LIMIT 1',
              [bid],
            ),
          );

      list.add(
        _ItemRaw(
          idItem: -1,
          idCard: otrosCard ?? -1, // ← usa la tarjeta del presupuesto activo
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

  void _recorteGlobal(List<_ItemAdjusted> adj, {required double ingreso}) {
    // ───────── helpers internos ─────────
    double _total() => adj.fold<double>(0, (s, e) => s + e.newBudget);

    // pasada 1 = “blanda”; pasada 2 = “dura”
    void _pasada({required bool hard}) {
      double exceso = _total() - ingreso;
      if (exceso <= 0) return;

      // (1) quitar colchón sobre lo ya gastado
      final sup =
          adj.where((e) => e.newBudget > e.raw.spent90).toList()
            ..sort((a, b) => b.newBudget.compareTo(a.newBudget));
      for (final e in sup) {
        if (exceso <= 0) break;
        final min = math.max(e.raw.spent90, 5);
        final cut = math.min(e.newBudget - min, exceso);
        e.newBudget -= cut;
        exceso -= cut;
      }

      // (2) prioridad general por tipo
      if (exceso > 0) {
        adj.sort((a, b) => _prio(b).compareTo(_prio(a)));
        for (final e in adj) {
          if (exceso <= 0) break;
          final min =
              hard
                  ? 5.0
                  : (e.raw.type == 3 /* Ahorros */
                      ? 5.0
                      : math.max(e.raw.plan + 5, 5.0));
          final cut = math.min(e.newBudget - min, exceso);
          e.newBudget -= cut;
          exceso -= cut;
        }
      }
    }

    /* 1ª y 2ª pasada (idénticas a la versión anterior) */
    _pasada(hard: false);
    _pasada(hard: true);

    // ── Plan C: todavía nos pasamos ──
    double diff = _total() - ingreso;
    if (diff > 0) {
      // 1) recorta GASTOS (type == 1)
      final gastos =
          adj.where((e) => e.raw.type == 1).toList()
            ..sort((a, b) => b.newBudget.compareTo(a.newBudget));
      for (final e in gastos) {
        if (diff <= 0) break;
        final cut = math.min(e.newBudget - 5, diff);
        e.newBudget -= cut;
        diff -= cut;
      }

      // 2) recorta AHORROS si sigue sobrando
      if (diff > 0) {
        final ahorros =
            adj.where((e) => e.raw.type == 3).toList()
              ..sort((a, b) => b.newBudget.compareTo(a.newBudget));
        for (final e in ahorros) {
          if (diff <= 0) break;
          final cut = math.min(e.newBudget - 5, diff);
          e.newBudget -= cut;
          diff -= cut;
        }
      }

      // 3) último recurso: escala proporcionalmente
      if (diff > 0) {
        final factor = ingreso / _total(); // 0 < factor < 1
        for (final e in adj) e.newBudget *= factor; // sin round5
      }

      // ── Ajuste final de céntimos ────────────────────────────────
      double excesoFinal = _total() - ingreso;
      if (excesoFinal > 0) {
        final eMayor = adj
            .where((e) => e.newBudget - 0.01 >= 5)
            .reduce((a, b) => a.newBudget > b.newBudget ? a : b);
        eMayor.newBudget -= excesoFinal;
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

  final fs = FirebaseFirestore.instance;
  final userDoc = fs.collection('users').doc(user.uid);
  final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

  final secColl = budgetDoc.collection('sections');
  final itmColl = budgetDoc.collection('items');

  final remoteSecIds = (await secColl.get()).docs.map((d) => d.id).toSet();
  final remoteItmIds = (await itmColl.get()).docs.map((d) => d.id).toSet();

  WriteBatch batch = fs.batch();
  int opCount = 0;
  Future<void> _commitIfNeeded() async {
    if (opCount >= 400) {
      await batch.commit();
      batch = fs.batch();
      opCount = 0;
    }
  }

  final Map<int, List<ItemUi>> byCard = {};
  for (final it in items) {
    byCard.putIfAbsent(it.idCard, () => []).add(it);
  }

  final db = SqliteManager.instance.db;
  final titleRows = await db.rawQuery(
    'SELECT id_card, title FROM card_tb WHERE id_card IN (${byCard.keys.join(",")})',
  );

  final cardTitle = {
    for (final r in titleRows) r['id_card'] as int: r['title'] as String,
  };

  for (final entry in byCard.entries) {
    final idCard = entry.key;
    final title = cardTitle[idCard] ?? 'Tarjeta $idCard';

    final secId = idCard.toString();
    batch.set(secColl.doc(secId), {'title': title}, SetOptions(merge: true));
    opCount++;
    await _commitIfNeeded();
    remoteSecIds.remove(secId);

    for (final it in entry.value) {
      final itId = it.idItem.toString();
      batch.set(itmColl.doc(itId), {
        'idCard': it.idCard,
        'idCategory': it.idCat,
        'name': it.catName,
        'amount': it.newPlan,
      }, SetOptions(merge: true));
      opCount++;
      await _commitIfNeeded();
      remoteItmIds.remove(itId);
    }
  }

  for (final orphanSec in remoteSecIds) {
    batch.delete(secColl.doc(orphanSec));
    opCount++;
    await _commitIfNeeded();
  }
  for (final orphanItem in remoteItmIds) {
    batch.delete(itmColl.doc(orphanItem));
    opCount++;
    await _commitIfNeeded();
  }

  if (opCount > 0) await batch.commit();
}
