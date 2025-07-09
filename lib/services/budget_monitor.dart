import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocketplanner/home/statisticsHome_screen.dart';
import 'package:pocketplanner/services/notification_services.dart';

class BudgetMonitor {
  static final _notifier = NotificationService();

  /// Chequeo rápido cada vez que el usuario añade una transacción
  Future<void> onTransactionAdded(TransactionData2 tx) async {
    await _checkOverspend(tx.id as int);
    await _checkSavingsProgress();
  }

  /// Ejecutado en background cada noche por WorkManager
  Future<void> runBackgroundChecks() async {
    // 1. Chequeo de fin de periodo
    await _checkPeriodEndNear();

    // 2. Chequeo de ahorros SOLO si es iOS (no confiar en Workmanager)
    if (Platform.isIOS) {
      await _checkSavingsProgress();
    }

    // 3. Programar notificaciones locales con anticipación
    await _scheduleLocalNotificationsForNextDays();
  }

  Future<void> _scheduleLocalNotificationsForNextDays() async {
    // Programar para los próximos 7 días (iOS necesita programación anticipada)
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));

      // Recordatorio diario
      _notifier.schedule(
        id: 300 + i,
        title: 'Registro diario',
        body: 'Registra tus transacciones de hoy',
        dateTime: date.copyWith(hour: 17, minute: 0),
      );

      // Chequeo de ahorros
      if (i <= 3) {
        // Últimos 3 días del periodo
        _notifier.schedule(
          id: 400 + i,
          title: 'Meta de ahorro',
          body: 'Revisa tu progreso de ahorros',
          dateTime: date.copyWith(hour: 12, minute: 0),
        );
      }
    }
  }

  //Previniendo sobregastos o anunciandolo
  Future<void> _checkOverspend(int itemId) async {
    // Traer el item con presupuesto y gasto acumulado
    final item = await BudgetRepository().getItem(itemId);
    if (item.budget == 0) return; // sin presupuesto → nada que avisar

    const earlyThreshold = 0.85; // 85 %
    final ratio = item.spent / item.budget; // p.ej. 0.92  (= 92 %)

    // Aviso preventivo (≥ 85 %)
    if (ratio >= earlyThreshold && ratio < 1.0) {
      await _notifier.showNow(
        title: '¡Cuidado con el gasto!',
        body:
            'Has utilizado el ${(ratio * 100).toStringAsFixed(1)} % de '
            'tu presupuesto para «${item.name}».',
      );
    }

    // Aviso de sobregasto  (≥ 100 %)
    if (ratio >= 1.0) {
      await _notifier.showNow(
        title: '¡Presupuesto excedido!',
        body:
            'Te has pasado de tu presupuesto para «${item.name}». '
            'Revisa y ajusta tus gastos.',
      );
    }
  }

  // Fin del periodo
  Future<void> _checkPeriodEndNear() async {
    final period = await BudgetRepository().currentPeriod();
    final now = DateTime.now();
    if (now.isAfter(period.end.subtract(const Duration(days: 1))) &&
        now.isBefore(period.end)) {
      // Solo programamos una vez
      await _notifier.schedule(
        id: 200, // id fijo para poder cancelarlo si el periodo cambia
        title: 'Fin de periodo',
        body: 'Hoy se acaba tu periodo de presupuesto. Ajustalo con IA!.',
        dateTime: period.end.subtract(const Duration(hours: 10)),
      );
    }
  }

  // Ahorro insuficiente a pocos días
  Future<void> _checkSavingsProgress() async {
    final savingItem = await BudgetRepository().getSavingsItem();
    if (savingItem == null) return;

    final period = await BudgetRepository().currentPeriod();
    final daysLeft = period.end.difference(DateTime.now()).inDays;

    if (daysLeft <= 3 && savingItem.amount < savingItem.target) {
      await _notifier.showNow(
        title: 'Meta de ahorro pendiente',
        body:
            'Te quedan $daysLeft días y has ahorrado ${savingItem.amount}/${savingItem.target}. ¡Aún puedes lograrlo!',
      );
    }
  }

  // Recordatorio diario para añadir transacciones
}

class BudgetRepository {
  BudgetRepository._internal();
  static final BudgetRepository _instance = BudgetRepository._internal();
  factory BudgetRepository() => _instance;

  final _db = FirebaseFirestore.instance;

  // Items
  Future<Item> getItem(int itemId) async {
    final doc = await _db.collection('items').doc(itemId as String?).get();
    return Item.fromDoc(doc.id, doc.data()!);
  }

  Future<Item?> getSavingsItem() async {
    final q =
        await _db
            .collection('items')
            .where('type', isEqualTo: 'AHORRO')
            .limit(1)
            .get();
    if (q.docs.isEmpty) return null;
    return Item.fromDoc(q.docs.first.id, q.docs.first.data());
  }

  // Periodo activo
  Future<BudgetPeriod> currentPeriod() async {
    final now = DateTime.now();
    final q =
        await _db
            .collection('periods')
            .where('start', isLessThanOrEqualTo: now)
            .where('end', isGreaterThan: now)
            .limit(1)
            .get();
    final doc = q.docs.first;
    return BudgetPeriod.fromDoc(doc.id, doc.data());
  }
}

// Modelo de Item y Periodo
// Estos modelos representan los datos de presupuesto y ahorro

class Item {
  final String id;
  final String name;
  final double budget;
  final double spent;
  final double target; // para ahorro

  Item({
    required this.id,
    required this.name,
    required this.budget,
    required this.spent,
    required this.target,
  });

  factory Item.fromDoc(String id, Map<String, dynamic> json) {
    return Item(
      id: id,
      name: json['name'] as String,
      budget: (json['budget'] ?? 0).toDouble(),
      spent: (json['spent'] ?? 0).toDouble(),
      target: (json['target'] ?? 0).toDouble(),
    );
  }

  get amount => null;
}

class BudgetPeriod {
  final String id;
  final DateTime start;
  final DateTime end;

  BudgetPeriod({required this.id, required this.start, required this.end});

  factory BudgetPeriod.fromDoc(String id, Map<String, dynamic> json) {
    return BudgetPeriod(
      id: id,
      start: (json['start'] as Timestamp).toDate(),
      end: (json['end'] as Timestamp).toDate(),
    );
  }
}
