import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pocketplanner/services/active_budget.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:pocketplanner/home/statisticsHome_screen.dart';

import '../database/sqlite_management.dart';

/// Motor principal del presupuesto IA
///
/// 1. Lee datos ↦ _fetchRaw()
/// 2. Predice factor ML ↦ _predictFactor()
/// 3. Optimiza con reglas ↦ _optimize()
/// 4. Devuelve lista ItemUi ↦ recalculate()
/// 5. Guarda y registra feedback ↦ persist()  /  registerRejected()
class BudgetEngine {
  BudgetEngine._();
  static final BudgetEngine instance = BudgetEngine._();

  // ──────────────────────────────────────────────────────────────
  // 1.  Garantizar que la tabla de feedback exista
  // ──────────────────────────────────────────────────────────────
  Future<void> _ensureFeedbackTable() async {
    final db = SqliteManager.instance.db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_feedback_tb (
        id_category INTEGER NOT NULL UNIQUE,
        accepted    INTEGER NOT NULL DEFAULT 0,
        edited      INTEGER NOT NULL DEFAULT 0,
        rejected    INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(id_category),
        FOREIGN KEY(id_category) REFERENCES category_tb(id_category)
          ON UPDATE NO ACTION
          ON DELETE CASCADE
      );
    ''');
  }

  // ────────────────── 1. TFLITE ──────────────────
  Interpreter? _tflite;
  Future<void> _ensureModelLoaded() async {
    if (_tflite != null) return;

    final dbDir = await getDatabasesPath();
    final file = File(p.join(dbDir, 'budget_base.tflite'));

    if (!await file.exists()) {
      final bytes = await rootBundle.load('assets/AI_model/budget_base.tflite');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _tflite = await Interpreter.fromFile(file);
  }

  // ────────────────── 2. DATA RAW ──────────────────
  Future<Map<int, _ItemRaw>> _fetchRaw() async {
    final db = SqliteManager.instance.db;

    final items = await db.rawQuery('''
      SELECT it.id_item      AS idItem,
             it.id_card      AS idCard,
             it.id_category  AS idCat,
             it.amount       AS plan,
             it.id_itemType  AS type,
            ct.name         AS catName         
      FROM item_tb it
      JOIN category_tb ct ON ct.id_category = it.id_category
    ''');

    final spentRows = await db.rawQuery('''
      SELECT id_category AS idCat, SUM(amount) AS spent
      FROM transaction_tb
      WHERE date(date) >= date('now','-30 day')
      GROUP BY id_category
    ''');

    final spentByCat = {
      for (final r in spentRows)
        r['idCat'] as int: (r['spent'] as num).toDouble(),
    };

    return {
      for (final r in items)
        r['idItem'] as int: _ItemRaw(
          idItem: r['idItem'] as int,
          idCard: r['idCard'] as int,
          idCat: r['idCat'] as int,
          plan: (r['plan'] as num).toDouble(),
          spent: spentByCat[r['idCat']] ?? 0.0,
          type: r['type'] as int,
          catName: r['catName'] as String,
        ),
    };
  }

  // =============== 3. FACTOR ML + PESO ADAPTATIVO ===============
  double _predictFactor(double plan) {
    final input = [
      [plan],
    ];
    final output = List.filled(1, List.filled(1, 0.0));
    _tflite?.run(input, output);
    return output[0][0];
  }

  // ────────────────── 3. FACTOR ML + PESO ADAPTATIVO ──────────────────
  Future<double> _adaptiveWeight(int idCat) async {
    final db = SqliteManager.instance.db;
    final row = await db.query(
      'ai_feedback_tb',
      columns: ['accepted', 'edited', 'rejected'],
      where: 'id_category = ?',
      whereArgs: [idCat],
    );

    if (row.isEmpty) return 0.5; // valor neutro para categorías “nuevas”

    final a = row.first['accepted'] as int? ?? 0;
    final e = row.first['edited'] as int? ?? 0;
    final r = row.first['rejected'] as int? ?? 0;
    final total = a + e + r;

    /*   Nueva valoración
    *   +2 por aceptado   ·   0 por editado   ·   –3 por rechazado
    *   El resultado se normaliza en 0.1 – 0.9 para no llegar a extremos.
    */
    final score = (2 * a - 3 * r).toDouble();
    return (0.5 + score / (4 * total)).clamp(0.1, 0.9);
  }

  // ────────────────── 4. OPTIMIZACIÓN ──────────────────
  Future<List<ItemUi>> _optimize(Map<int, _ItemRaw> raw) async {
    /* —­­  Ingresos fijos (card 1)  —­­ */
    final ingresoTotal = raw.values
        .where((r) => r.idCard == 1)
        .fold<double>(0, (s, r) => s + r.plan);

    final items = <ItemUi>[];

    /* —­­ 1. Ajuste individual por ML + reglas —­­ */
    for (final r in raw.values) {
      double newAmount = r.plan;
      final weight = await _adaptiveWeight(r.idCat);

      /* ML base solo para variables (id_itemType = 2) */
      if (r.type == 2) {
        final factor = _predictFactor(r.plan) * weight;
        newAmount = r.plan + factor; // sin tope inicial
      }

      final ratio = r.plan == 0 ? 0 : (r.spent - r.plan) / r.plan;

      /* 1-A. Overspend > 5 %  ⇒  sube con elasticidad */
      if (ratio > .05) {
        final elastic = (r.plan + r.spent) / 2; // punto medio
        final hardCap = r.plan * 2; // máx. +100 %
        newAmount = math.max(newAmount, math.min(elastic, hardCap));
      }

      /* 1-B. Underspend en variables (≠ ahorros)  ⇒  baja un 15 % máx */
      if (r.idCard != 3 && r.type == 2 && ratio < -.05) {
        newAmount = math.max(r.spent, r.plan * 0.85);
      }

      items.add(
        ItemUi(
          idItem: r.idItem,
          idCard: r.idCard,
          idCat: r.idCat,
          catName: r.catName,
          aiPlan: newAmount, // sugerencia IA
          spent: r.spent,
          newPlan: newAmount.ceilToDouble(),
          oldPlan: r.plan,
        ),
      );
    }

    /* —­­ 2. Balance global —­­ */
    double egresos = items
        .where((i) => i.idCard != 1)
        .fold<double>(0, (s, i) => s + i.newPlan);
    double sobra = ingresoTotal - egresos; // puede ser negativo

    if (sobra < 0) {
      /* 2-A. Falta dinero  ⇒  recortar primero variables (no ahorros) */
      final vars = items.where(
        (i) => i.idCard != 3 && i.newPlan > i.spent,
      ); // margen recortable
      for (final it in vars) {
        final reducible = it.newPlan - math.max(it.spent, it.oldPlan);
        final cut = math.min(reducible, -sobra);
        it.newPlan -= cut;
        sobra += cut;
        if (sobra >= 0) break;
      }

      /* 2-B. Si aún falta, tocar ahorros pero nunca por debajo del plan original */
      if (sobra < 0) {
        final ahorros = items.where((i) => i.idCard == 3);
        for (final it in ahorros) {
          final reducible = it.newPlan - it.oldPlan;
          final cut = math.min(reducible, -sobra);
          it.newPlan -= cut;
          sobra += cut;
          if (sobra >= 0) break;
        }
      }
    } else if (sobra > 0) {
      /* 2-C. Sobra dinero  ⇒  refuerza ahorros que van bien (spent ≥ plan) */
      final ahorrosOK =
          items.where((i) => i.idCard == 3 && i.spent >= i.oldPlan).toList();

      if (ahorrosOK.isNotEmpty) {
        final asignar = sobra * 0.50; // 50 % del excedente
        final share = (asignar / ahorrosOK.length * 100).floor() / 100;
        for (final it in ahorrosOK) it.newPlan += share;
      }
    }

    return items;
  }

  // ────────────────── 5. API PÚBLICA ──────────────────
  Future<List<ItemUi>> recalculate() async {
    await _ensureFeedbackTable();
    await _ensureModelLoaded();
    final raw = await _fetchRaw();
    return await _optimize(raw);
  }

  ///   Guarda montos y registra feedback (Aceptado / Editado)
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
}

// ═════════ DTOs ═════════
class _ItemRaw {
  final int idItem, idCard, idCat, type;
  final String catName;
  final double plan, spent;
  const _ItemRaw({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.catName,
    required this.plan,
    required this.spent,
    required this.type,
  });
}

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
