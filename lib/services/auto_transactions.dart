import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/services/budget_monitor.dart';
import 'package:pocketplanner/services/date_range.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/sqlite_management.dart';
import 'active_budget.dart';

/// Servicio que crea las transacciones automáticas necesarias

class AutoRecurringService {
  Future<int> run(BuildContext context) async {
    final db = SqliteManager.instance.db;
    final int? bid = Provider.of<ActiveBudget>(context, listen: false).idBudget;
    if (bid == null) return 0; // sin presupuesto

    // Rango de fechas del periodo activo
    final PeriodRange range = await periodRangeForBudget(bid);
    if (range == PeriodRange.empty) return 0;

    // salir si no hay transacciones en absoluto
    final int nRows =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transaction_tb WHERE id_budget = ?',
            [bid],
          ),
        ) ??
        0;
    if (nRows == 0) return 0;

    int insertedCount = 0;
    final String startIso = range.start.toIso8601String();
    final String endIso = range.end.toIso8601String();
    final DateTime today = DateTime.now();
    final String todayIso = _asIsoDate(today);

    await db.transaction((txn) async {
      final rows = await txn.query(
        'transaction_tb',
        where: 'id_budget = ? AND date >= ? AND date <= ?',
        whereArgs: [bid, startIso, endIso],
      );

      // Agrupa por frecuencia
      final Map<int, List<Map<String, Object?>>> byFreq = {};
      for (final r in rows) {
        byFreq.putIfAbsent(r['id_frequency'] as int, () => []).add(r);
      }

      // FRECUENCIA 2 : TODOS LOS DÍAS
      if (!byFreq.containsKey(2) && !byFreq.containsKey(3)) {
        // Si no hay absolutamente ninguno de freq 2 ni 3 podemos saltarnos
      } else {
        // indexa por "firma" para búsquedas rápidas
        final signaturesToday = <String>{};
        final rowsToday = await txn.query(
          'transaction_tb',
          where:
              'id_budget = ? AND date(date) = date(?) AND id_frequency IN (2,3)',
          whereArgs: [bid, todayIso],
        );
        for (final r in rowsToday) {
          signaturesToday.add(_signature(r));
        }

        // 2 y 3 usan la misma lógica, solo difiere el filtro por día laboral
        for (final freq in [2, 3]) {
          if (!byFreq.containsKey(freq)) continue;

          // si hoy es sábado/domingo y freq == 3 -> no hacer nada
          if (freq == 3 &&
              (today.weekday == DateTime.saturday ||
                  today.weekday == DateTime.sunday))
            continue;

          for (final row in byFreq[freq]!) {
            final sig = _signature(row);
            if (signaturesToday.contains(sig)) continue; // ya existe hoy

            await txn.insert('transaction_tb', {
              ...row, // clona todos los campos
              'date': todayIso,
              'id_transact': null, // deja que autoincremente
            });

            insertedCount++;
          }
        }
      }

      // FRECUENCIA 4 : CADA SEMANA
      if (byFreq.containsKey(4)) {
        // Últimos 7 días para comprobar duplicados
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        final dupRows = await txn.query(
          'transaction_tb',
          where: 'id_budget = ? AND date >= ? AND id_frequency = 4',
          whereArgs: [bid, sevenDaysAgo.toIso8601String()],
        );
        final dupSignatures =
            dupRows.map<String>(_signature).toSet(); // firmas últimos 7 días

        for (final row in byFreq[4]!) {
          final sig = _signature(row);
          if (dupSignatures.contains(sig)) continue; // ya hay una esta semana

          await txn.insert('transaction_tb', {
            ...row,
            'date': todayIso,
            'id_transact': null,
          });

          insertedCount++;
        }
      }

      // FRECUENCIA 5 : CADA MES
      if (byFreq.containsKey(5)) {
        final firstOfMonth =
            DateTime(today.year, today.month, 1).toIso8601String();
        final dupRows = await txn.query(
          'transaction_tb',
          where: 'id_budget = ? AND date >= ? AND id_frequency = 5',
          whereArgs: [bid, firstOfMonth],
        );
        final dupSignatures =
            dupRows.map<String>(_signature).toSet(); // firmas de este mes

        for (final row in byFreq[5]!) {
          final sig = _signature(row);
          if (dupSignatures.contains(sig)) continue; // ya existe este mes

          await txn.insert('transaction_tb', {
            ...row,
            'date': todayIso,
            'id_transact': null,
          });

          insertedCount++;
        }
      }
    });

    return insertedCount;
  }

  Future<BudgetPeriod?> currentPeriod(Database db, int idBudget) async {
    final PeriodRange r = await periodRangeForBudget(idBudget);
    if (r == PeriodRange.empty) return null;

    // construimos un id “sintético” con las fechas
    final pid = '${r.start.toIso8601String()}_${r.end.toIso8601String()}';

    return BudgetPeriod(id: pid, start: r.start, end: r.end);
  }

  /// Devuelve YYYY-MM-DD (sin hora) en ISO-8601
  String _asIsoDate(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d); // mantiene timezone local

  /// Firma única para saber si “es la misma” transacción (sin la fecha)
  String _signature(Map<String, Object?> r) =>
      '${r['id_category']}_${r['amount']}_${r['id_frequency']}';
}
