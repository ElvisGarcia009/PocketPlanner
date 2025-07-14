import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/sqlite_management.dart';
import '../services/active_budget.dart';
import '../services/date_range.dart';

class BudgetEngineBackend {
  BudgetEngineBackend._();
  static final BudgetEngineBackend instance = BudgetEngineBackend._();

  static const _apiUrl =
      'https://budget-prediction-api-d6tj.onrender.com/predict';
  static const _timeout = Duration(seconds: 60);

  /// Recalcula las predicciones detectando quincenal o mensual:
  Future<List<CategoryPrediction>> recalculate(
      double income,
      BuildContext ctx,
  ) async {
    // 1) Obtén el rango completo
    final fullRange = await periodRangeForBudget(ctx.read<ActiveBudget>().idBudget!);
    if (fullRange == PeriodRange.empty) return [];

    // Si el rango cubre todo un mes, partimos en dos quincenas:
    final start = fullRange.start;
    final end   = fullRange.end;
    final isFullMonth = start.day == 1 && end == start.endOfMonth;

    if (!isFullMonth) {
      // comportamiento normal quincenal
      final stats = await _fetchTransactionsForRange(ctx, start, end);
      return _predictFromStats(stats);
    }

    // → Rango mensual: lo dividimos en dos quincenas
    final mid = DateTime(start.year, start.month, 15);
    final firstRange  = DateTimeRange(start: start, end: mid);
    final secondRange = DateTimeRange(start: mid.add(Duration(days: 1)), end: end);

    // 2) Fetch y predict primeras 15 días
    final stats1 = await _fetchTransactionsForRange(ctx, firstRange.start, firstRange.end);
    final preds1 = await _predictFromStats(stats1);

    // 3) Fetch y predict segunda quincena
    final stats2 = await _fetchTransactionsForRange(ctx, secondRange.start, secondRange.end);
    final preds2 = await _predictFromStats(stats2);

    // 4) Unimos ambas predicciones (sumando por categoría)
    final Map<int, CategoryPrediction> combined = {};
    for (final p in preds1) {
      combined[p.catId] = CategoryPrediction(
        catId: p.catId,
        category: p.category,
        prediction: p.prediction + (preds2.firstWhere(
          (q) => q.catId == p.catId,
          orElse: () => CategoryPrediction(catId: p.catId, category: p.category, prediction: 0),
        ).prediction),
      );
    }
    // categorías nuevas de la segunda quincena
    for (final p in preds2) {
      if (!combined.containsKey(p.catId)) {
        combined[p.catId] = p;
      }
    }

    return combined.values.toList();
  }

  /// Llama al endpoint usando los stats pre-agregados
  Future<List<CategoryPrediction>> _predictFromStats(
      Map<int, _CatStats> statsByCat,
  ) async {
    if (statsByCat.isEmpty) return [];

    final payload = statsByCat.values.map((s) => {
      'category': s.catName,
      'partial_sum': s.partialSum,
      'day_of_fortnight': s.dayOfFortnight,
      'percent_of_fortnight': s.percentOfFortnight,
      'avg_daily_spending_so_far': s.avgDaily,
      'days_left_in_fortnight': s.daysLeft,
    }).toList();

    final uri = Uri.parse(_apiUrl);
    final res = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Backend error ${res.statusCode}');
    }

    final root = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> list = root['predictions'];
    final db = SqliteManager.instance.db;

    final results = <CategoryPrediction>[];
    for (final m in list.cast<Map<String, dynamic>>()) {
      final name = m['category'] as String;
      final pred = (m['prediction'] as num).toDouble();
      final rows = await db.query('category_tb',
          columns: ['id_category'], where: 'name = ?', whereArgs: [name], limit: 1);
      final id = rows.isNotEmpty ? rows.first['id_category'] as int : -1;
      results.add(CategoryPrediction(catId: id, category: name, prediction: pred));
    }
    return results;
  }

  /// Extrae y agrega las transacciones en un rango arbitrario
  Future<Map<int, _CatStats>> _fetchTransactionsForRange(
      BuildContext ctx,
      DateTime start,
      DateTime end,
  ) async {
    final db = SqliteManager.instance.db;
    final bid = ctx.read<ActiveBudget>().idBudget;
    if (bid == null) return {};

    final refDate = start;
    final totalDays = end.difference(start).inDays + 1;
    final today = DateTime.now().isBefore(end) ? DateTime.now() : end;
    final dayIdx = today.difference(refDate).inDays + 1;
    final daysLeft = totalDays - dayIdx;
    final percent = dayIdx / totalDays;

    final rows = await db.rawQuery('''
      SELECT t.id_category AS cat, ct.name AS name, t.amount
      FROM transaction_tb t
      JOIN category_tb ct ON t.id_category = ct.id_category
      WHERE t.id_budget = ? AND t.date BETWEEN ? AND ?
    ''', [bid, start.toIso8601String(), end.toIso8601String()]);

    final stats = <int, _CatStats>{};
    for (final r in rows) {
      final c = r['cat'] as int;
      final nm = r['name'] as String;
      final amt = (r['amount'] as num).toDouble();
      final st = stats.putIfAbsent(
          c,
          () => _CatStats(
                catId: c,
                catName: nm,
                partialSum: 0,
                dayOfFortnight: dayIdx,
                percentOfFortnight: percent,
                avgDaily: 0,
                daysLeft: daysLeft,
              ));
      st.partialSum += amt;
    }

    stats.values.forEach((s) => s.avgDaily = s.partialSum / dayIdx);
    return stats;
  }
}

/// Modelo de estadística por categoría
class _CatStats {
  final int catId;
  final String catName;
  double partialSum;
  final int dayOfFortnight;
  final double percentOfFortnight;
  double avgDaily;
  final int daysLeft;
  _CatStats({
    required this.catId,
    required this.catName,
    required this.partialSum,
    required this.dayOfFortnight,
    required this.percentOfFortnight,
    required this.avgDaily,
    required this.daysLeft,
  });
}

/// Resultado de la predicción por categoría
class CategoryPrediction {
  final int catId;
  final String category;
  final double prediction;
  const CategoryPrediction({
    required this.catId,
    required this.category,
    required this.prediction,
  });
}

/// Extensión para obtener fin de mes
extension _DateUtils on DateTime {
  DateTime get endOfMonth => DateTime(year, month + 1, 0);
}
