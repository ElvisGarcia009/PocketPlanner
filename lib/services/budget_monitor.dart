/*─────────────────────────────────────────────────────────────────
  budget_monitor.dart   (SQLite-only + AutoRecurringService)
─────────────────────────────────────────────────────────────────*/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:pocketplanner/services/notification_settings.dart';
import 'package:pocketplanner/services/auto_transactions.dart'; // ← tu clase
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

/*──────────────── BUDGET MONITOR ────────────────*/

class BudgetMonitor {
  final NotificationService _notifier = NotificationService();

  final savings_id = 3;
  final outcomes_id = 1;

  Future<void> onTransactionAdded(BuildContext ctx, int catID) async {
    final int? idBudget = ctx.read<ActiveBudget>().idBudget;
    if (idBudget == null) return;

    await _checkOverspend(idBudget, catID, outcomes_id);
    await _CheckSavingDone(idBudget, catID, savings_id);
  }

  /*  Llama desde WorkManager o en el arranque de la app
      BudgetMonitor().runBackgroundChecks(context);
  */
  Future<void> runBackgroundChecks(int idBudget) async {
    await _checkPeriodEndNear(idBudget);
    await _checkSavingsProgress(idBudget); // corre en todas las plataformas
    await _scheduleLocalNotificationsForNextDays();
  }

  /*─────────────── Overspend ───────────────*/

  Future<void> _checkOverspend(int idBudget, catID, outcomes_id) async {
    final item = await BudgetRepository().getItem(idBudget, catID, outcomes_id);
    if (item.budget == 0) return;

    debugPrint(item.spent.toString() + " y " + item.budget.toString());

    const early = 0.85;
    final ratio = item.spent / item.budget;

    if (ratio >= early && ratio < 1) {
      await _notifier.showNow(
        title: '¡Cuidado con el gasto!',
        body:
            'Has usado el ${(ratio * 100).toStringAsFixed(1)} % '
            'de tu plan en «${item.name}».',
      );
    } else if (ratio == 1) {
      await _notifier.showNow(
        title: '¡Ten cuidado!',
        body: 'Has gastado todo en tu plan de «${item.name}».',
      );
    } else if (ratio >= 1) {
      await _notifier.showNow(
        title: '¡Presupuesto excedido!',
        body: 'Te has pasado del límite de «${item.name}».',
      );
    }
  }

  Future<void> _CheckSavingDone(int idBudget, int catID, int savings_id) async {
    final item = await BudgetRepository().getItem(idBudget, catID, savings_id);
    if (item.budget == 0) return;

    const early = 0.85;
    final ratio = item.spent / item.budget;

    if (ratio >= early && ratio < 1) {
      await _notifier.showNow(
        title: '¡Sigue así!',
        body:
            'Llevas ahorrado un ${(ratio * 100).toStringAsFixed(1)} % '
            'de tu plan en «${item.name}».',
      );
    } else if (ratio == 1) {
      await _notifier.showNow(
        title: '¡Bien hecho!',
        body: 'Has cumplido con tu meta de «${item.name}».',
      );
    } else if (ratio >= 1) {
      await _notifier.showNow(
        title: '¡A por más!',
        body: 'Has ahorrado más del plan en «${item.name}».',
      );
    }
  }

  /*────────────── Fin de periodo ───────────*/

  Future<void> _checkPeriodEndNear(int idBudget) async {
    final period = await BudgetRepository().currentPeriod(idBudget);
    if (period == null) return;

    final now = DateTime.now();
    final DateTime targetDay = period.end.subtract(const Duration(days: 1));

    // Comparamos solo el día (ignoramos hora)
    if (now.year == targetDay.year &&
        now.month == targetDay.month &&
        now.day == targetDay.day) {
      await _notifier.schedule(
        id: 200,
        title: 'Fin del periodo',
        body: 'Tu periodo está terminando. ¡Ajusta tu presupuesto con IA!',
        dateTime: DateTime(now.year, now.month, now.day, 15, 0), // 3:00 PM
      );
    }
  }

  /*──────────────– Ahorros (varios ítems) ────────────────*/
  Future<void> _checkSavingsProgress(int idBudget) async {
    final List<Item> savings = await BudgetRepository().getSavingsItems(
      idBudget,
    );
    if (savings.isEmpty) return;

    final period = await BudgetRepository().currentPeriod(idBudget);
    if (period == null) return;

    final now = DateTime.now();
    final daysLeft = period.end.difference(now).inDays;

    // Espaciar notificaciones: hoy, mañana, pasado…
    int offset = 0;

    for (final sv in savings) {
      if (sv.spent >= sv.target) continue; // ya cumplido

      final remaining = sv.target - sv.spent;
      final title = 'Ahorro «${sv.name}» pendiente';
      final body =
          'Quedan $daysLeft días y faltan '
          '${NumberFormat.compact().format(remaining)} '
          'para tu meta de ${NumberFormat.compact().format(sv.target)}.';

      final when = now.add(Duration(days: offset));
      await _notifier.schedule(
        id: 500 + offset, // 500, 501, 502…  idénticos entre lanzamientos
        title: title,
        body: body,
        dateTime: when.copyWith(hour: 12, minute: 0),
      );

      offset++; // siguiente notificación un día después
    }
  }

  /*────────────── Recordatorios ───────────*/

  Future<void> _scheduleLocalNotificationsForNextDays() async {
    for (int i = 0; i < 7; i++) {
      await _notifier.cancel(300 + i);
      await _notifier.cancel(400 + i);
    }
    for (int i = 0; i < 7; i++) {
      final d = DateTime.now().add(Duration(days: i));
      _notifier.schedule(
        id: 300 + i,
        title: 'Registro diario',
        body: '¡Registra tus transacciones de hoy!',
        dateTime: d.copyWith(hour: 17, minute: 0),
      );
      if (i <= 3) {
        _notifier.schedule(
          id: 400 + i,
          title: 'Meta de ahorro',
          body: 'Revisa tu avance de ahorros',
          dateTime: d.copyWith(hour: 12, minute: 0),
        );
      }
    }
  }
}

class BudgetRepository {
  BudgetRepository._();
  static final BudgetRepository _inst = BudgetRepository._();
  factory BudgetRepository() => _inst;

  final Database _db = SqliteManager.instance.db;

  Future<Item> getItem(int idBudget, int idCat, int movement_id) async {
    final targetRow = await _db.rawQuery(
      '''
    SELECT COALESCE(SUM(it.amount), 0) as value 
    FROM   item_tb it
    JOIN   card_tb ca ON ca.id_card = it.id_card
    JOIN   category_tb cat on cat.id_category = it.id_category
    WHERE  it.id_category = ?
      AND  ca.id_budget   = ?
      AND  cat.id_movement = ?
    ''',
      [idCat, idBudget, movement_id],
    );

    final double target = (targetRow.first['value'] as num).toDouble();

    /* ── 2.  Periodo actual (mensual / quincenal)  ─────────────────────── */
    final BudgetPeriod? pr = await AutoRecurringService().currentPeriod(
      _db,
      idBudget,
    );
    if (pr == null) {
      return Item(
        id: '$idCat',
        name: 'Categoría $idCat',
        budget: target,
        spent: 0,
        target: target,
      );
    }

    /* ── 3.  Gasto acumulado en el periodo  ────────────────────────────── */
    final spentRow = await _db.rawQuery(
      '''
    SELECT COALESCE(SUM(amount),0) as value
    FROM   transaction_tb
    WHERE  id_category = ?
      AND  id_budget   = ?
      AND  date >= ? AND date <= ?
    ''',
      [idCat, idBudget, pr.start.toIso8601String(), pr.end.toIso8601String()],
    );
    final double spent = (spentRow.first['value'] as num).toDouble();

    /* ── 4.  Nombre de la categoría (opcional, para mostrar bonito) ────── */
    final nameRow = await _db.query(
      'category_tb',
      columns: ['name'],
      where: 'id_category = ?',
      whereArgs: [idCat],
      limit: 1,
    );
    final String catName =
        nameRow.isNotEmpty
            ? nameRow.first['name'] as String
            : 'Categoría $idCat';

    return Item(
      id: '$idCat',
      name: catName,
      budget: target,
      spent: spent,
      target: target,
    );
  }

  /*── Todos los ítems de ahorro (id_itemType = 3) ───────────────*/
  Future<List<Item>> getSavingsItems(int idBudget) async {
    const int savingTypeId = 3;

    // Ítems de ahorro dentro del presupuesto
    final rows = await _db.rawQuery(
      '''
    SELECT it.id_item, it.id_category, it.amount AS target, ca.title
    FROM   item_tb it
    JOIN   card_tb ca ON ca.id_card = it.id_card
    WHERE  ca.id_card = ?
      AND  ca.id_budget = ?
    ''',
      [savingTypeId, idBudget],
    );
    if (rows.isEmpty) return [];

    // Rango de fechas del periodo actual
    final BudgetPeriod? pr = await AutoRecurringService().currentPeriod(
      _db,
      idBudget,
    );
    if (pr == null || pr == _PeriodRange.empty) return [];

    final List<Item> list = [];

    for (final r in rows) {
      final idItem = r['id_item'] as int;
      final idCat = r['id_category'] as int;
      final target = (r['target'] as num).toDouble();
      final name = r['title'] as String? ?? 'Ahorro';

      // Total ahorrado durante el periodo
      final spent =
          Sqflite.firstIntValue(
            await _db.rawQuery(
              '''
        SELECT COALESCE(SUM(amount),0)
        FROM   transaction_tb
        WHERE  id_category = ?
          AND  id_budget   = ?
          AND  date >= ? AND date <= ?
        ''',
              [
                idCat,
                idBudget,
                pr.start.toIso8601String(),
                pr.end.toIso8601String(),
              ],
            ),
          )!;

      list.add(
        Item(
          id: '$idItem',
          name: name,
          budget: target,
          spent: (spent as num).toDouble(),
          target: target,
        ),
      );
    }

    return list;
  }

  /*── Periodo activo ─——————————————————————————————*/
  Future<BudgetPeriod?> currentPeriod(int idBudget) async {
    final BudgetPeriod? pr = await AutoRecurringService().currentPeriod(
      _db,
      idBudget,
    );
    if (pr == _PeriodRange.empty) return null;
    return BudgetPeriod(
      id: '${pr?.start}_${pr?.end}',
      start: pr!.start,
      end: pr.end,
    );
  }
}

/*──────────────── MODELOS ────────────────*/

class Item {
  final String id, name;
  final double budget, spent, target;
  Item({
    required this.id,
    required this.name,
    required this.budget,
    required this.spent,
    required this.target,
  });
}

class BudgetPeriod {
  final String id;
  final DateTime start, end;
  BudgetPeriod({required this.id, required this.start, required this.end});
}

class _PeriodRange {
  final DateTime start;
  final DateTime end;
  const _PeriodRange(this.start, this.end);
  static var empty = _PeriodRange._();
  _PeriodRange._() : start = DateTime(1970), end = DateTime(1970);
}
