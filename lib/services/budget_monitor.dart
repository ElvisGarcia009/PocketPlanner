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
    await _checkPeriodEndNear();
    await _scheduleDailyReminder();
    await _checkSavingsProgress();
  }

  /* ──────────────────────────── 1) Overspend ─────────────────────────── */
  Future<void> _checkOverspend(int itemId) async {
    final item = await BudgetRepository().getItem(itemId);
    if (item.budget == 0) return;

    const threshold = 0.9; // 90 %
    if (item.spent / item.budget >= threshold) {
      await _notifier.showNow(
        title: '¡Cuidado con el gasto!',
        body:
            'Estás por superar el presupuesto de "${item.name}". Revisa tus finanzas.',
      );
    }
  }

  /* ─────────────────────── 2) Fin de periodo inminente ────────────────── */
  Future<void> _checkPeriodEndNear() async {
    final period = await BudgetRepository().currentPeriod(); // start/end dates
    final now    = DateTime.now();
    if (now.isAfter(period.end.subtract(const Duration(days: 1))) &&
        now.isBefore(period.end)) {
      // Solo programamos una vez
      await _notifier.schedule(
        id: 200, // id fijo para poder cancelarlo si el periodo cambia
        title: 'Fin de periodo',
        body: 'Mañana acaba tu periodo de presupuesto. Ajusta tu presupuesto!.',
        dateTime: period.end.subtract(const Duration(hours: 10)),
      );
    }
  }

  /* ────────────── 3) Ahorro insuficiente a pocos días ─────────────── */
  Future<void> _checkSavingsProgress() async {
    final savingItem = await BudgetRepository().getSavingsItem();
    if (savingItem == null) return;

    final period = await BudgetRepository().currentPeriod();
    final daysLeft =
        period.end.difference(DateTime.now()).inDays;

    if (daysLeft <= 3 && savingItem.amount < savingItem.target) {
      await _notifier.showNow(
        title: 'Meta de ahorro pendiente',
        body:
            'Te quedan $daysLeft días y has ahorrado ${savingItem.amount}/${savingItem.target}. ¡Aún puedes lograrlo!',
      );
    }
  }

  /* ─────────── 4) Recordatorio diario para añadir transacciones ────────── */
  Future<void> _scheduleDailyReminder() async {
    const id = 300;
    final tomorrow7pm =
        DateTime.now().add(const Duration(days: 1)).copyWith(hour: 19, minute: 0);

    await _notifier.schedule(
      id: id,
      title: 'Registro diario',
      body: 'No olvides registrar tus transacciones de hoy.',
      dateTime: tomorrow7pm,
    );
  }
}

class BudgetRepository {
  BudgetRepository._internal();
  static final BudgetRepository _instance = BudgetRepository._internal();
  factory BudgetRepository() => _instance; // patrón singleton

  final _db = FirebaseFirestore.instance;

  /* ─────────── Items ─────────── */
  Future<Item> getItem(int itemId) async {
    final doc = await _db.collection('items').doc(itemId as String?).get();
    return Item.fromDoc(doc.id, doc.data()!);
  }

  Future<Item?> getSavingsItem() async {
    final q = await _db
        .collection('items')
        .where('type', isEqualTo: 'AHORRO')
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return Item.fromDoc(q.docs.first.id, q.docs.first.data());
  }

  /* ─────────── Periodo activo ─────────── */
  Future<BudgetPeriod> currentPeriod() async {
    final now = DateTime.now();
    final q = await _db
        .collection('periods')
        .where('start', isLessThanOrEqualTo: now)
        .where('end', isGreaterThan: now)
        .limit(1)
        .get();
    final doc = q.docs.first;
    return BudgetPeriod.fromDoc(doc.id, doc.data());
  }
}

/* -----------------
   Modelos de apoyo
------------------- */
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
      spent:  (json['spent']  ?? 0).toDouble(),
      target: (json['target'] ?? 0).toDouble(),
    );
  }
  
  get amount => null;
}

class BudgetPeriod {
  final String id;
  final DateTime start;
  final DateTime end;

  BudgetPeriod({
    required this.id,
    required this.start,
    required this.end,
  });

  factory BudgetPeriod.fromDoc(String id, Map<String, dynamic> json) {
    return BudgetPeriod(
      id: id,
      start: (json['start'] as Timestamp).toDate(),
      end:   (json['end']   as Timestamp).toDate(),
    );
  }
}