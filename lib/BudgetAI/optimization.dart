import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pocketplanner/BudgetAI/budget_engine.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:provider/provider.dart';
import '../database/sqlite_management.dart';
import '../services/date_range.dart';

/// Resultado final de la optimización
class ItemUi {
  final int idItem, idCard, idCat;
  final String catName;
  final double oldPlan; // plan actual
  final double spent; // gastado en el periodo
  final double aiPlan; // predicción cruda de la IA
  double newPlan; // sugerencia final

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

class Optimization {
  Optimization._();
  static final Optimization instance = Optimization._();

  static const _tol = 500; // tolerancia absoluta
  static double _round5(double x) => math.max(0, (x / 5).round() * 5);

  Future<List<ItemUi>> recalculate(double income, BuildContext ctx) async {
    // Obtengo items/raw de SQLite
    final raw = await _fetchRaw(ctx);
    if (raw.isEmpty) return [];

    // Llamo al backend por predicciones
    final preds = await BudgetEngineBackend.instance.recalculate(income, ctx);
    final predByCat = {for (var p in preds) p.catId: p.prediction};

    // Calculo cada sugerencia
    final List<ItemUi> recos = [];
    for (final r in raw) {
      final plan = r.plan;
      final spent = r.spent;
      final pred = predByCat[r.idCat] ?? spent;

      // si no hay desviación significativa, mantengo el plan
      if ((plan - spent).abs() <= _tol && (pred - plan).abs() <= _tol) {
        recos.add(
          ItemUi(
            idItem: r.idItem,
            idCard: r.idCard,
            idCat: r.idCat,
            catName: r.catName,
            oldPlan: plan,
            spent: spent,
            aiPlan: pred,
            newPlan: plan,
          ),
        );
        continue;
      }

      if (spent == 0) {
        recos.add(
          ItemUi(
            idItem: r.idItem,
            idCard: r.idCard,
            idCat: r.idCat,
            catName: r.catName,
            oldPlan: plan,
            spent: spent,
            aiPlan: spent,
            newPlan: plan,
          ),
        );
        continue;
      }

      // caso pred > plan → subimos; pred < plan → bajamos
      // sugerencia base = promedio simple
      final mid = (plan + pred) / 2.0;
      // margenes ±10 %
      final low = _round5(mid * 0.90);
      final high = _round5(mid * 1.10);
      // elegimos centrado en mid
      var sug = _round5(mid);

      // garantizo que quede dentro del rango [low, high]
      sug = sug.clamp(low, high);

      recos.add(
        ItemUi(
          idItem: r.idItem,
          idCard: r.idCard,
          idCat: r.idCat,
          catName: r.catName,
          oldPlan: plan,
          spent: spent,
          aiPlan: pred,
          newPlan: sug,
        ),
      );
    }

    // Verifico total vs ingreso con 10 % de buffer
    final buffer = 0.10 * income;
    var totalSug = recos.fold(0.0, (s, it) => s + it.newPlan);
    if (totalSug > income - buffer) {
      // factor de escala uniforme
      final factor = (income - buffer) / totalSug;
      for (var it in recos) {
        it.newPlan = _round5(it.newPlan * factor);
      }
    }

    return recos;
  }

  /// Raw item desde SQLite
  Future<List<_ItemRaw>> _fetchRaw(BuildContext ctx) async {
    final db = SqliteManager.instance.db;
    final bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
    if (bid == null) return [];

    // rango de la quincena / mes
    final range = await periodRangeForBudget(bid);
    if (range == PeriodRange.empty) return [];
    final sIso = range.start.toIso8601String();
    final eIso = range.end.toIso8601String();

    // items con plan
    final items = await db.rawQuery(
      '''
      SELECT it.id_item AS idItem,
             it.id_card AS idCard,
             it.id_category AS idCat,
             it.amount AS plan,
             it.id_itemType AS type,
             ct.name AS catName
      FROM item_tb it
      JOIN card_tb ca USING(id_card)
      JOIN category_tb ct USING(id_category)
      WHERE ca.id_budget = ? 
      AND ca.title != 'Ingresos' AND it.id_itemType = 2; 
    ''',
      [bid],
    );

    // gasto por categoría
    final spentRows = await db.rawQuery(
      '''
      SELECT id_category AS idCat,
             SUM(amount) AS spent
      FROM transaction_tb
      WHERE id_budget = ? AND date BETWEEN ? AND ?
      GROUP BY id_category
    ''',
      [bid, sIso, eIso],
    );

    final spentMap = {
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
          plan: (r['plan'] as num).toDouble(),
          spent: spentMap[r['idCat']] ?? 0.0,
        ),
    ];
  }
}

/// Modelo interno
class _ItemRaw {
  final int idItem, idCard, idCat;
  final String catName;
  final double plan, spent;
  const _ItemRaw({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.catName,
    required this.plan,
    required this.spent,
  });
}

// Persistencia de los cambios
Future<void> persist(List<ItemUi> items, BuildContext ctx) async {
  final db = SqliteManager.instance.db;
  final int? idBudget = ctx.read<ActiveBudget>().idBudget;
  if (idBudget == null) return; 

  await db.transaction((txn) async {
    for (final it in items) {
      // Ítem existente (UPDATE)
      if (it.idItem > 0) {
        await txn.update(
          'item_tb',
          {'amount': it.newPlan},
          where: '''
              id_item = ?
              AND id_card IN (
                SELECT id_card FROM card_tb WHERE id_budget = ?
              )
            ''',
          whereArgs: [it.idItem, idBudget],
        );
      }
      // Ítem nuevo (INSERT)
      else {
        final cardCheck = await txn.query(
          'card_tb',
          columns: ['id_card'],
          where: 'id_card = ? AND id_budget = ?',
          whereArgs: [it.idCard, idBudget],
          limit: 1,
        );
        if (cardCheck.isEmpty) continue;
        await txn.insert('item_tb', {
          'id_card': it.idCard,
          'id_category': it.idCat,
          'amount': it.newPlan,
          'id_itemType': 2,
          'date_crea': DateTime.now().toIso8601String(),
        });
      }
    }
  });

  // Sincronización incremental con Firestore
  _syncWithFirebaseIncremental(ctx, items);
}

/// Sincroniza solamente los items modificados/incrementales con Firestore
Future<void> _syncWithFirebaseIncremental(
  BuildContext ctx,
  List<ItemUi> items,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final int? bid = ctx.read<ActiveBudget>().idBudget;
  if (bid == null) return;

  final db = SqliteManager.instance.db;
  final fs = FirebaseFirestore.instance;
  final budgetDoc = fs
      .collection('users')
      .doc(user.uid)
      .collection('budgets')
      .doc(bid.toString());
  final secColl = budgetDoc.collection('sections');
  final itmColl = budgetDoc.collection('items');

  // Recopilo ids locales
  final localCardIds =
      (await db.rawQuery('SELECT id_card FROM card_tb WHERE id_budget = ?', [
        bid,
      ])).map((r) => r['id_card'].toString()).toSet();
  final localItemIds =
      (await db.rawQuery(
        '''
      SELECT it.id_item
      FROM item_tb it
      JOIN card_tb ca USING(id_card)
      WHERE ca.id_budget = ?
      ''',
        [bid],
      )).map((r) => r['id_item'].toString()).toSet();

  // Fetch remotos
  final remoteSecIds = (await secColl.get()).docs.map((d) => d.id).toSet();
  final remoteItmIds = (await itmColl.get()).docs.map((d) => d.id).toSet();

  var batch = fs.batch();
  int op = 0;
  Future<void> commitIfNeeded() async {
    if (op >= 400) {
      await batch.commit();
      batch = fs.batch();
      op = 0;
    }
  }

  // Agrupo por tarjeta
  final byCard = <int, List<ItemUi>>{};
  for (final it in items) {
    byCard.putIfAbsent(it.idCard, () => []).add(it);
  }
  // Títulos de tarjetas
  final titleRows = await db.rawQuery(
    'SELECT id_card, title FROM card_tb WHERE id_card IN (${byCard.keys.join(",")})',
  );
  final cardTitle = {
    for (var r in titleRows) r['id_card'] as int: r['title'] as String,
  };

  // Upsert secciones y items
  for (final entry in byCard.entries) {
    final secId = entry.key.toString();
    batch.set(secColl.doc(secId), {
      'title': cardTitle[entry.key] ?? 'Tarjeta ${entry.key}',
    }, SetOptions(merge: true));
    op++;
    await commitIfNeeded();
    remoteSecIds.remove(secId);

    for (final it in entry.value) {
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
      final itmId = realId.toString();
      batch.set(itmColl.doc(itmId), {
        'idCard': it.idCard,
        'idCategory': it.idCat,
        'idItemType': 2,
        'name': it.catName,
        'amount': it.newPlan,
      }, SetOptions(merge: true));
      op++;
      await commitIfNeeded();
      remoteItmIds.remove(itmId);
    }
  }

  // Borrar huérfanos
  for (final sid in remoteSecIds.difference(localCardIds)) {
    batch.delete(secColl.doc(sid));
    op++;
    await commitIfNeeded();
  }
  for (final iid in remoteItmIds.difference(localItemIds)) {
    batch.delete(itmColl.doc(iid));
    op++;
    await commitIfNeeded();
  }

  if (op > 0) await batch.commit();
}
