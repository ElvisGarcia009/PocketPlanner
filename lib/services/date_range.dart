import 'package:sqflite/sqflite.dart';
import '../database/sqlite_management.dart';

/// --- mismo value-object que ya tienes ---
class PeriodRange {
  final DateTime start;
  final DateTime end;
  const PeriodRange(this.start, this.end);
  static var empty = PeriodRange._();
  PeriodRange._() : start = DateTime(1970), end = DateTime(1970);
}

/// Devuelve el rango (start-end) del presupuesto [budgetId]
Future<PeriodRange> periodRangeForBudget(int budgetId) async {
  final Database db = SqliteManager.instance.db;

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
    // Mensual
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));
    return PeriodRange(start, end);
  } else {
    // Quincenal
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

/// SELECT … FROM transaction_tb restringido al periodo activo
Future<List<Map<String, Object?>>> selectTransactionsInPeriod({
  required int budgetId,
  required String? extraWhere, // puede ser null
  required List<Object?> extraArgs, // idem
}) async {
  final db = SqliteManager.instance.db;
  final range = await periodRangeForBudget(budgetId);
  if (range == PeriodRange.empty) return const [];

  // WHERE principal con rango
  final buffer = StringBuffer('id_budget = ? AND date >= ? AND date <= ?');
  final args = <Object?>[
    budgetId,
    range.start.toIso8601String(),
    range.end.toIso8601String(),
  ];

  // condiciones extra opcionales
  if (extraWhere != null && extraWhere.trim().isNotEmpty) {
    buffer.write(' AND ($extraWhere)');
    args.addAll(extraArgs);
  }

  return db.rawQuery(
    '''
  SELECT t.*, 
         c.name AS category_name, 
         f.name AS frequency_name,
         m.name AS movement_name
  FROM transaction_tb t
  LEFT JOIN category_tb c ON c.id_category = t.id_category
  LEFT JOIN frequency_tb f ON f.id_frequency = t.id_frequency
  LEFT JOIN movement_tb m ON m.id_movement = t.id_movement
  WHERE t.id_budget = ? 
    AND t.date >= ? 
    AND t.date <= ?
  ORDER BY t.date DESC
''',
    [budgetId, range.start.toIso8601String(), range.end.toIso8601String()],
  );
}
