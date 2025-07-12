import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*  Modelo que ya usas para mapear la fila de SQLite  */
class BudgetSql2 {
  final int idBudget;
  final String name;
  final int idPeriod;
  BudgetSql2({
    required this.idBudget,
    required this.name,
    required this.idPeriod,
  });

  factory BudgetSql2.fromMap(Map<String, Object?> m) => BudgetSql2(
    idBudget: m['id_budget'] as int,
    name: m['name'] as String,
    idPeriod: m['id_budgetPeriod'] as int,
  );
}

/*──────────────────── ACTIVE BUDGET ────────────────────*/

class ActiveBudget extends ChangeNotifier {
  static const _prefsKey = 'active_budget_id';

  int? idBudget;
  String? name;
  int? idPeriod;

  /* ──────────────── INIT ──────────────── */

  /// Carga el presupuesto activo:
  ///   1) Lo intenta leer de SharedPrefs.
  ///   2) Si no existe, toma el primero de la tabla y lo guarda.
  Future<void> initFromSqlite(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    int? storedId = prefs.getInt(_prefsKey);

    Map<String, Object?>? row;

    if (storedId != null) {
      /*  Caso normal: ya había un id_guardado  */
      final res = await db.query(
        'budget_tb',
        where: 'id_budget = ?',
        whereArgs: [storedId],
        limit: 1,
      );
      if (res.isNotEmpty) row = res.first;
    }

    if (row == null) {
      /*  Primera vez o id_guardado no existe. Tomamos el primero  */
      final res = await db.query('budget_tb', orderBy: 'id_budget', limit: 1);
      if (res.isNotEmpty) {
        row = res.first;
        await prefs.setInt(_prefsKey, row['id_budget'] as int);
      }
    }

    if (row != null) {
      final b = BudgetSql2.fromMap(row);
      idBudget = b.idBudget;
      name = b.name;
      idPeriod = b.idPeriod;
      notifyListeners();
    }
  }

  /* ─────────────── CHANGE ─────────────── */

  /// Cambia el presupuesto activo y lo persiste.
  void change({
    required int idBudgetNew,
    required String nameNew,
    required int idPeriodNew,
  }) async {
    idBudget = idBudgetNew;
    name = nameNew;
    idPeriod = idPeriodNew;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, idBudgetNew);
  }
}
