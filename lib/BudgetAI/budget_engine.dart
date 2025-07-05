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

  /*══════════════════════════════════════════════════════════════╗
  ║ 0. TABLAS AUXILIARES (crea una vez)                          ║
  ╚══════════════════════════════════════════════════════════════╝*/
  Future<void> _ensureTables() async {
    final db = SqliteManager.instance.db;
    /* – Feedback brutos (aceptado / editado / rechazado) – */
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_feedback_tb (
        id_category INTEGER PRIMARY KEY,
        accepted    INTEGER NOT NULL DEFAULT 0,
        edited      INTEGER NOT NULL DEFAULT 0,
        rejected    INTEGER NOT NULL DEFAULT 0
      );
    ''');

    /* – Preferencia aprendida – */
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_pref_tb (
        id_category INTEGER PRIMARY KEY,
        pref_budget REAL    NOT NULL,
        samples     INTEGER NOT NULL
      );
    ''');
  }

  /*══════════════════════════════════════════════════════════════╗
  ║ 1. Cargar modelo TFLite (no re-entrena)                      ║
  ╚══════════════════════════════════════════════════════════════╝*/
  Interpreter? _tflite;
  Future<void> _ensureModelLoaded() async {
    if (_tflite != null) return;
    final dbDir = await getDatabasesPath();
    final file = File(p.join(dbDir, 'budget_adjuster.tflite'));
    if (!await file.exists()) {
      final bytes = await rootBundle.load('assets/AI_model/budget_adjuster.tflite');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _tflite = await Interpreter.fromFile(file);
  }

  double _predictTFLite(double spent90, double plan) {
    final meanDaily = spent90 / 90.0;
    final input = [[spent90, meanDaily, plan]];
    final output = List.filled(1, List.filled(1, 0.0));
    _tflite?.run(input, output);
    return output[0][0];
  }

  /*══════════════════════════════════════════════════════════════╗
  ║ 2. Ajuste con preferencia local                               ║
  ╚══════════════════════════════════════════════════════════════╝*/
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
    final n    = rows.first['samples']     as int;

    // weight ↑ con el nº de muestras (hasta 0.8)
    final w = math.min(0.8, n / (n + 2));   // 1 muestra ≈0.33 | ≥8 ≈0.80
    return modelPred * (1 - w) + pref * w;
  }

  /*══════════════════════════════════════════════════════════════╗
  ║ 3. API pública: recalculate()                                 ║
  ╚══════════════════════════════════════════════════════════════╝*/
  static const _tol = 350.0;
  static double _round5(double x) => math.max(0, (x / 5).round() * 5);

  Future<List<ItemUi>> recalculate(double income, BuildContext ctx) async {
    await _ensureTables();
    await _ensureModelLoaded();

    final raw = await _fetchRaw(ctx);
    final List<_ItemAdjusted> adj = [];

    /* ——-- 3-A. Sugerencia por ítem (modelo + preferencia) --—— */
    for (final r in raw) {
      final diff = (r.spent90 - r.plan).abs();
      double sug = (diff <= _tol) ? r.plan : _predictTFLite(r.spent90, r.plan);
      sug = await _blendWithUserPref(r.idCat, sug);      // 👈 mezcla
      sug = _round5(sug);

      /* reglas gasto / ahorro */
      if (r.type == 1) {
        if (r.spent90 < r.plan && sug >= r.plan) sug = _round5(r.spent90);
        if (r.spent90 > r.plan && sug <= r.plan) sug = _round5(math.max(r.spent90, r.plan + 5));
      } else if (r.type == 3) {
        if (r.spent90 > r.plan && sug <= r.plan) sug = _round5(math.max(r.spent90, r.plan + 5));
        if (r.spent90 < r.plan && sug >= r.plan) sug = _round5(math.max(r.spent90, r.plan * .8));
      }
      adj.add(_ItemAdjusted(raw: r, newBudget: sug));
    }

    /* ——-- 3-B. Tope global (income) --—— */
    double sobra = adj.fold(0.0, (s, e) => s + e.newBudget) - income;
    if (sobra > 0) _recorteGlobal(adj, sobra);

    return adj;
  }

  /*══════════════════════════════════════════════════════════════╗
  ║ 4. Persistencia + aprendizaje                                 ║
  ╚══════════════════════════════════════════════════════════════╝*/
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
          'id_item'     : it.idItem,       // -1 → deja que SQLite auto-asigne
          'id_card'     : it.idCard,
          'id_category' : it.idCat,
          'amount'      : it.newPlan,
          'id_itemType' : 1,
          'date_crea'   : DateTime.now().toIso8601String(),
        });
      }

      // 2) feedback
      final col = (it.newPlan == it.aiPlan) ? 'accepted' : 'edited';
      await txn.rawInsert('''
        INSERT INTO ai_feedback_tb(id_category,$col)
        VALUES(?,1)
        ON CONFLICT(id_category) DO UPDATE SET $col = $col + 1;
      ''', [it.idCat]);

      // 3) preferencia incremental
      await txn.rawInsert('''
        INSERT INTO ai_pref_tb(id_category,pref_budget,samples)
        VALUES(?,?,1)
        ON CONFLICT(id_category) DO UPDATE
          SET samples     = samples + 1,
              pref_budget = (pref_budget * (samples) + ?) / (samples + 1);
      ''', [it.idCat, it.newPlan, it.newPlan]);
    }
  });

  // 4) tras commit → Firebase (opcional; quítalo si quieres 100 % offline)
  _syncWithFirebaseIncremental(ctx, items);
}

  /*══════════════════════════════════════════════════════════════╗
  ║ 5. Helpers internos (_fetchRaw & recorte global)              ║
  ╚══════════════════════════════════════════════════════════════╝*/
Future<List<_ItemRaw>> _fetchRaw(BuildContext ctx) async {
  final db  = SqliteManager.instance.db;
  final bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
  if (bid == null) return [];

  // 1. rango
  final range = await _periodRangeForBudget(bid);
  if (range == PeriodRange.empty) return [];

  final sIso = range.start.toIso8601String();
  final eIso = range.end.toIso8601String();

  // 2. ítems con transacciones
  final items = await db.rawQuery('''
    SELECT DISTINCT it.id_item  idItem,
           it.id_card          idCard,
           it.id_category      idCat,
           it.amount           plan,
           it.id_itemType      type,
           ct.name             catName
    FROM item_tb it
    JOIN transaction_tb t ON t.id_category = it.id_category
    JOIN category_tb   ct ON ct.id_category = it.id_category
    WHERE t.id_budget = ? AND t.date BETWEEN ? AND ?;
  ''', [bid, sIso, eIso]);

  // 3. gasto por categoría (incluye huérfanas)
  final spentRows = await db.rawQuery('''
    SELECT COALESCE(id_category,-1) idCat, SUM(amount) spent
    FROM   transaction_tb
    WHERE  id_budget = ? AND date BETWEEN ? AND ?
    GROUP  BY COALESCE(id_category,-1);
  ''', [bid, sIso, eIso]);

  final spent = {
    for (final r in spentRows) r['idCat'] as int: (r['spent'] as num).toDouble()
  };

  // 4. lista con ítems del plan
  final list = <_ItemRaw>[
    for (final r in items)
      _ItemRaw(
        idItem : r['idItem'] as int,
        idCard : r['idCard'] as int,
        idCat  : r['idCat']  as int,
        catName: r['catName'] as String,
        type   : r['type']   as int,
        plan   : (r['plan']  as num).toDouble(),
        spent90: spent[r['idCat']] ?? 0.0,
      ),
  ];

  // 5. transacciones sin plan  →  “Otros” (provisional)
  const kOtrosCat = 7;
  final catsEnPlan = {for (final it in list) it.idCat};

  double extraOtros = 0.0;
  spent.forEach((cat, amt) {
    if (cat == kOtrosCat) return;
    if (!catsEnPlan.contains(cat)) extraOtros += amt;
  });

  final idxOtros = list.indexWhere((e) => e.idCat == kOtrosCat);

  if (idxOtros >= 0) {
    // Ya existe “Otros” → sólo acumulamos gasto extra
    list[idxOtros] = list[idxOtros].copyWith(
      spent90: list[idxOtros].spent90 + extraOtros,
    );
  } else if (extraOtros > 0 || spent.containsKey(kOtrosCat)) {
    // Generamos registro provisional (idItem = -1 marca que aún no existe)
    list.add(_ItemRaw(
      idItem : -1,                  // <- aún no está en BD
      idCard : 2,
      idCat  : kOtrosCat,
      catName: 'Otros',
      type   : 1,
      plan   : 0,
      spent90: (spent[kOtrosCat] ?? 0) + extraOtros,
    ));
  }
  return list;
}


  void _recorteGlobal(List<_ItemAdjusted> adj, double exceso) {
    // colchón
    final sup = adj.where((e) => e.newBudget > e.raw.spent90).toList()
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
        final min = (e.raw.type == 3) ? 5.0 : math.max(e.raw.spent90 - _tol, 5.0);
        while (e.newBudget - 5 >= min && exceso > 0) {
          e.newBudget -= 5;
          exceso -= 5;
        }
        e.newBudget = _round5(e.newBudget);
      }
    }
  }

  /// ⟹  SELECT id_budgetPeriod FROM budget_tb …   y calcula rango
  Future<PeriodRange> _periodRangeForBudget(int budgetId) async {
    final db = SqliteManager.instance.db;
    final res = await db.query(
      'budget_tb',
      columns: ['id_budgetPeriod'],
      where: 'id_budget = ?',
      whereArgs: [budgetId],
      limit: 1,
    );
    if (res.isEmpty) return PeriodRange.empty;

    final int periodId = res.first['id_budgetPeriod'] as int; 
    final now = DateTime.now();

    if (periodId == 1) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
      return PeriodRange(start, end);
    } else {
      // quincenal
      if (now.day <= 15) {
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, 15);
        return PeriodRange(start, end);
      } else {
        final start = DateTime(now.year, now.month, 16);
        final end = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        return PeriodRange(start, end);
      }
    }
  }



  // prioridad para recortes (3=último, 1=primero)
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

/*──────── modelos ───────*/
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
  _ItemAdjusted({required this.raw,required this.newBudget})
      : super(idItem: raw.idItem,idCard: raw.idCard,idCat: raw.idCat,
              catName: raw.catName,oldPlan: raw.plan,spent: raw.spent90,
              aiPlan: newBudget,newPlan: newBudget);
}

/*──────── DTO público ───*/
class ItemUi {
  final int idItem,idCard,idCat;
  final String catName;
  final double oldPlan,spent,aiPlan;
  double newPlan;
  ItemUi({required this.idItem,required this.idCard,required this.idCat,
          required this.catName,required this.oldPlan,required this.spent,
          required this.aiPlan,required this.newPlan});
}
Future<void> _syncWithFirebaseIncremental(
  BuildContext ctx,
  List<ItemUi> items,
) async {
  /* 0. Seguridad básica */
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // sesión expirada

  final int? bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
  if (bid == null) return; // sin presupuesto

  /* 1. Referencias remotas */
  final fs = FirebaseFirestore.instance;
  final userDoc = fs.collection('users').doc(user.uid);
  final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

  final secColl = budgetDoc.collection('sections');
  final itmColl = budgetDoc.collection('items');

  /* 2. Snapshot remoto actual */
  final remoteSecIds = (await secColl.get()).docs.map((d) => d.id).toSet();
  final remoteItmIds = (await itmColl.get()).docs.map((d) => d.id).toSet();

  /* 3. Batch incremental (400 ops máx) */
  WriteBatch batch = fs.batch();
  int opCount = 0;
  Future<void> _commitIfNeeded() async {
    if (opCount >= 400) {
      await batch.commit();
      batch = fs.batch();
      opCount = 0;
    }
  }

  /* 3-a) UPSERT · secciones e items */
  //  agrupa por idCard para no golpear SQLite otra vez
  final Map<int, List<ItemUi>> byCard = {};
  for (final it in items) {
    byCard.putIfAbsent(it.idCard, () => []).add(it);
  }

  //  ➜ título de la tarjeta (id_card)  ⇢  SELECT sólo una vez por idCard
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

    // ► sección
    final secId = idCard.toString();
    batch.set(secColl.doc(secId), {'title': title}, SetOptions(merge: true));
    opCount++;
    await _commitIfNeeded();
    remoteSecIds.remove(secId);

    // ► items de esa sección
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

  /* 3-b) Eliminaciones remotas: lo que ya no existe localmente */
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

  /* 4. Commit final, si quedó algo pendiente */
  if (opCount > 0) await batch.commit();
}
