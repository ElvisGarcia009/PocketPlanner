// lib/ia/budget_engine.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;


/// Objeto que realiza toda la cadena:
///   1) Lee ingresos, gastos, ahorros y transacciones
///   2) Llama al modelo budget_base.tflite para “pre-decir” variaciones
///   3) Aplica la misma lógica de optimización que el script Python
///   4) Devuelve una lista de ItemUi con los montos nuevos
///
///  ▸ `recalculate()`   → ejecuta todo y devuelve la lista
///  ▸ `persist(list)`   → graba los nuevos montos en item_tb si el usuario acepta
class BudgetEngine {
  BudgetEngine._();
  static final BudgetEngine instance = BudgetEngine._();

  // —————————————————————————————————————————————————————
  // MODELO  T F L I T E
  // —————————————————————————————————————————————————————
Interpreter? _tflite;

Future<void> _ensureModelLoaded() async {
  if (_tflite != null) return;

  final dbDir = await getDatabasesPath();
  final modelPath = p.join(dbDir, 'budget_base.tflite');
  final modelFile = File(modelPath);

  if (!await modelFile.exists()) {
    final byteData = await rootBundle.load('assets/budget_base.tflite');
    await modelFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  }

  _tflite = await Interpreter.fromFile(modelFile);
}


  /// 1) -------------------------------------------------
  /// Lee BD → regresa Map<idItem, ItemRaw>
  Future<Map<int, _ItemRaw>> _fetchRaw() async {
    final db = SqliteManager.instance.db;

    // a) Items con su categoría / card
    final items = await db.rawQuery('''
      SELECT it.id_item      AS idItem,
             it.id_card      AS idCard,
             it.id_category  AS idCat,
             it.amount       AS plan,
             it.id_itemType  AS type
      FROM item_tb it
    ''');

    // b) Spent últimos 30 días
    final spentRows = await db.rawQuery('''
      SELECT id_category AS idCat,
             SUM(amount) AS spent
      FROM transaction_tb
      WHERE date(date) >= date('now', '-30 day')
      GROUP BY id_category
    ''');

    final spentByCat = {
      for (final r in spentRows) r['idCat'] as int: (r['spent'] as num).toDouble()
    };

    // c) Map final
    return {
      for (final r in items)
        r['idItem'] as int: _ItemRaw(
          idItem : r['idItem'] as int,
          idCard : r['idCard'] as int,
          idCat  : r['idCat']  as int,
          plan   : (r['plan']  as num).toDouble(),
          spent  : spentByCat[r['idCat']] ?? 0.0,
          type   : r['type'] as int,             // 1= fijo, 2= variable
        ),
    };
  }

  /// 2) -------------------------------------------------
  /// Predice el factor de ajuste con el modelo TFLite
  double _predictFactor(double plan) {
    // Modelo esperaba shape [1,1] (float32)
    final input  = [ [ plan ] ];
    final output = List.filled(1, List.filled(1, 0.0));
    _tflite?.run(input, output);
    return output[0][0] as double;
  }

  /// 3) -------------------------------------------------
  /// Aplica las mismas reglas que el script (resumen simplificado)
  List<ItemUi> _optimize(Map<int, _ItemRaw> raw) {
    final ingresoTotal = raw.values
        .where((r) => r.idCard == 1)
        .fold<double>(0, (s, r) => s + r.plan);

    // a) variables → punto de partida: plan ± predicción ML
    final items = <ItemUi>[];
    for (final r in raw.values) {
      double newAmount = r.plan;

      if (r.type == 2) {
        final factor = _predictFactor(r.plan);
        newAmount = (r.plan + factor).clamp(0, r.plan * 1.15);
      }

      // sobre-gasto >5 %  → sube gradualmente
      if ((r.spent - r.plan) / (r.plan == 0 ? 1 : r.plan) > 0.05) {
        newAmount = math.max(newAmount, math.min(r.spent, r.plan * 1.15));
      }

      // infra-gasto >5 %  → baja gradualmente (solo variables)
      if (r.type == 2 &&
          (r.spent - r.plan) / (r.plan == 0 ? 1 : r.plan) < -0.05) {
        newAmount = math.max(r.spent, r.plan * 0.85);
      }

      items.add(ItemUi(
        idItem : r.idItem,
        idCard : r.idCard,
        idCat  : r.idCat,
        oldPlan: r.plan,
        spent  : r.spent,
        newPlan: newAmount.ceilToDouble(),   // redondeo ↑
      ));
    }

    // b) balance ingresos – egresos  (muy resumido)
    final totalEgresos = items
        .where((i) => i.idCard != 1)
        .fold<double>(0, (s, i) => s + i.newPlan);

    double sobra = ingresoTotal - totalEgresos;
    if (sobra > 0) {
      // 50 % para ahorros cumplidos
      final candidatos =
          items.where((i) => i.idCard == 3 && i.spent >= i.oldPlan).toList();
      if (candidatos.isNotEmpty) {
        final asignar = sobra * .50;
        final share   = (asignar / candidatos.length * 100).floor() / 100;
        for (final c in candidatos) c.newPlan += share;
        sobra -= asignar;
      }
      // lo demás queda como liquidez (no se toca)
    }

    return items;
  }

  // 4) -------------------------------------------------
  Future<List<ItemUi>> recalculate() async {
    await _ensureModelLoaded();
    final raw    = await _fetchRaw();
    final result = _optimize(raw);
    return result;
  }

  /// Guarda los ajustes definitivos en item_tb
  Future<void> persist(List<ItemUi> items) async {
    final db = SqliteManager.instance.db;
    final batch = db.batch();
    for (final it in items) {
      batch.update(
        'item_tb',
        {'amount': it.newPlan},
        where: 'id_item = ?',
        whereArgs: [it.idItem],
      );
    }
    await batch.commit(noResult: true);
  }
}

// ══════════════════════════════════════════════════════════
// Helpers DTO
// ══════════════════════════════════════════════════════════
class _ItemRaw {
  final int idItem, idCard, idCat, type;
  final double plan, spent;
  _ItemRaw({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.plan,
    required this.spent,
    required this.type,
  });
}

class ItemUi {
  final int    idItem, idCard, idCat;
  final double oldPlan, spent;
  double newPlan;                // mutable: se ajusta al final
  ItemUi({
    required this.idItem,
    required this.idCard,
    required this.idCat,
    required this.oldPlan,
    required this.spent,
    required this.newPlan,
  });
}
