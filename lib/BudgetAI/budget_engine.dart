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

class BudgetEngine {
  BudgetEngine._();
  static final BudgetEngine instance = BudgetEngine._();

  // ───────── 1. Cargar modelo TFLite (3 features) ─────────
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

  double _predictBudget({required double spent90, required double plan}) {
    final meanDaily = spent90 / 90.0;
    final input = [
      [spent90, meanDaily, plan],
    ]; // shape 1×3
    final output = List.filled(1, List.filled(1, 0.0));
    _tflite?.run(input, output);
    return output[0][0];
  }

  // ───────── 2. Leer datos crudos (90 d) ─────────
  Future<List<_ItemRaw>> _fetchRaw() async {
    final db = SqliteManager.instance.db;

    // items con su tipo (1=gasto, 3=ahorro…)
    final items = await db.rawQuery('''
      SELECT id_item       AS idItem,
             id_card       AS idCard,
             id_category   AS idCat,
             amount        AS plan,
             id_itemType   AS type,
             name          AS catName
      FROM   item_tb
    ''');

    // gasto últimos 90 días por categoría
    final spentRows = await db.rawQuery('''
      SELECT id_category AS idCat,
             SUM(amount) AS spent
      FROM   transaction_tb
      WHERE  date(date) >= date('now','-90 day')
      GROUP  BY id_category
    ''');

    final spentByCat = {
      for (final r in spentRows)
        r['idCat'] as int: (r['spent'] as num).toDouble(),
    };

    return [
      for (final r in items)
        _ItemRaw(
          idItem: r['idItem'] as int,
          idCard: r['idCard'] as int,
          idCat: r['idCat'] as int,
          catName: r['catName'] as String,
          type: r['type'] as int,
          plan: (r['plan'] as num).toDouble(),
          spent90: spentByCat[r['idCat']] ?? 0.0,
        ),
    ];
  }

  // ───────── 3. Ajuste con reglas de negocio ─────────

  static const _tol = 350.0;
  static double _round5(double x) => math.max(0, (x / 5).round() * 5);

  Future<List<_ItemAdjusted>> recalculate({required double income}) async {
    await _ensureModelLoaded();
    final raw = await _fetchRaw();

    // propuesta inicial
    final adjusted = <_ItemAdjusted>[];
    for (final r in raw) {
      final diff = (r.spent90 - r.plan).abs();

      double newBudget;
      if (diff <= _tol) {
        newBudget = _round5(r.plan);
      } else {
        double pred = _round5(_predictBudget(spent90: r.spent90, plan: r.plan));

        // prioridades
        if (r.type == 1) {
          // GASTO
          if (r.spent90 < r.plan && pred >= r.plan) {
            pred = _round5(r.spent90); // reducir
          } else if (r.spent90 > r.plan && pred <= r.plan) {
            pred = _round5(math.max(r.spent90, r.plan + 5)); // subir
          }
        } else if (r.type == 3) {
          // AHORRO
          if (r.spent90 > r.plan && pred <= r.plan) {
            pred = _round5(math.max(r.spent90, r.plan + 5)); // aumentar
          } else if (r.spent90 < r.plan && pred >= r.plan) {
            pred = _round5(math.max(r.spent90, r.plan * 0.8)); // bajar s/margen
          }
        }
        newBudget = pred;
      }

      adjusted.add(_ItemAdjusted(raw: r, newBudget: newBudget));
    }

    // 4. Tope global (income)
    double exceso = adjusted.fold(0.0, (s, e) => s + e.newBudget) - income;

    if (exceso > 0) {
      
      // 4-A colchón: partidas con superávit
      final surplus =
          adjusted.where((e) => e.newBudget > e.raw.spent90).toList()
            ..sort((a, b) => b.newBudget.compareTo(a.newBudget));

      for (final e in surplus) {
        if (exceso <= 0) break;
        final minimo = math.max(e.raw.spent90, 5);
        final reducible = e.newBudget - minimo;
        if (reducible <= 0) continue;
        final cut = math.min(reducible, exceso);
        e.newBudget = _round5(e.newBudget - cut);
        exceso -= cut;
      }

      // 4-B recorte por prioridad
      if (exceso > 0) {
        adjusted.sort((a, b) => _prio(b).compareTo(_prio(a))); // 3→2→1
        for (final e in adjusted) {
          if (exceso <= 0) break;
          final minimo =
              (e.raw.type == 3) ? 5.0 : math.max(e.raw.spent90 - _tol, 5.0);
          while (e.newBudget - 5 >= minimo && exceso > 0) {
            e.newBudget -= 5;
            exceso -= 5;
          }
          e.newBudget = _round5(e.newBudget);
        }
      }
    }

    return adjusted;
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

// ───────── modelos internos ─────────
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
}

class _ItemAdjusted {
  final _ItemRaw raw;
  double newBudget;
  _ItemAdjusted({required this.raw, required this.newBudget});
}

 Future<void> persist(List<ItemUi> items, BuildContext ctx) async {
    final db = SqliteManager.instance.db;
    final batch = db.batch();

    // a) almacenar nuevo monto
    for (final it in items) {
      batch.update(
        'item_tb',
        {'amount': it.newPlan},
        where: 'id_item = ?',
        whereArgs: [it.idItem],
      );
    }

    _syncWithFirebaseIncremental(
      ctx,
      items,
    ); // Sin await, no es necesario que el usuario espere a que llegue a FireBase

    // b) feedback accepted / edited
    for (final it in items) {
      final col = (it.newPlan == it.aiPlan) ? 'accepted' : 'edited';
      batch.rawInsert(
        '''
        INSERT INTO ai_feedback_tb(id_category,$col)
        VALUES(?,1)
        ON CONFLICT(id_category)
        DO UPDATE SET $col = $col + 1
      ''',
        [it.idCat],
      );
    }
    await batch.commit(noResult: true);
  }

  /// ❌  El usuario canceló totalmente la propuesta
  Future<void> registerRejected(List<ItemUi> items) async {
    final db = SqliteManager.instance.db;
    final batch = db.batch();
    for (final it in items) {
      batch.rawInsert(
        '''
        INSERT INTO ai_feedback_tb(id_category,rejected) VALUES(?,1)
        ON CONFLICT(id_category) DO UPDATE SET rejected = rejected + 1
      ''',
        [it.idCat],
      );
    }
    await batch.commit(noResult: true);
  }


// ═════════ DTOs ═════════

class ItemUi {
  final int idItem, idCard, idCat;
  final String catName;
  final double oldPlan, spent, aiPlan; // ← sugerencia IA
  double newPlan; // ← editable

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
