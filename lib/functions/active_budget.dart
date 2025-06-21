// lib/state/active_budget.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/sqlite_management.dart';

class ActiveBudget extends ChangeNotifier {
  int?    idBudget;
  String? name;
  int?    idPeriod;

  /// Lee de SQLite el primer presupuesto y lo deja como activo
  Future<void> initFromSqlite(Database db) async {
    final maps = await db.query('budget_tb', orderBy: 'id_budget', limit: 1);
    if (maps.isNotEmpty) {
      final b = BudgetSql.fromMap(maps.first);
      idBudget = b.idBudget;
      name     = b.name;
      idPeriod = b.idPeriod;
    }
    notifyListeners();
  }

  /// Cambia el presupuesto activo y avisa a todos los listeners
  void change({
    required int idBudgetNew,
    required String nameNew,
    required int idPeriodNew,
  }) {
    idBudget = idBudgetNew;
    name     = nameNew;
    idPeriod = idPeriodNew;
    notifyListeners();
  }
}


