import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocketplanner/services/budget_monitor.dart';
import 'package:pocketplanner/services/notification_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/sqlite_management.dart';
import '../home/home_screen.dart';
import '../services/active_budget.dart';
import '../services/periods.dart';
import '../services/sync_first_time.dart';
import '../auth/LoginSignup_screen.dart';
import 'dart:io' show Platform;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:workmanager/workmanager.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthFlowScreen();

    return FutureBuilder<void>(
      future: _initEverything(context, user.uid),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeScreen();
      },
    );
  }

  Future<void> _initEverything(BuildContext ctx, String uid) async {
    await SqliteManager.instance.initDbForUser(uid);

    await FirstTimeSync.instance.syncFromFirebaseIfNeeded(ctx);

    // inicialización de notificaciones
    await NotificationService().init();

    tz.initializeTimeZones();
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    // Se ejecuta cada noche a las 12 del medio dia
    if (Platform.isAndroid) {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'budget-check',
        'daily-budget-task',
        frequency: const Duration(hours: 24),
        initialDelay: _delayUntil(12, 0),
      );
    } else {
      iosNotificationSettings;
    }

    await Provider.of<ActiveBudget>(
      ctx,
      listen: false,
    ).initFromSqlite(SqliteManager.instance.db);

    final inserted = await AutoRecurringService().run(ctx);

    if (inserted > 0 && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Se insertaron $inserted transacciones automáticas 🧾'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      );
    }
  }
}

//  Utilidad: delay hasta una hora “hh:mm” local de hoy; si ya pasó, hasta mañana
Duration _delayUntil(int hour, int minute) {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, hour, minute);
  if (target.isBefore(now)) target = target.add(const Duration(days: 1));
  return target.difference(now);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    final int? idBudget = prefs.getInt('active_budget_id');

    if (idBudget == null) {
      // No hay presupuesto activo -> no hacemos chequeos
      return Future.value(true);
    }

    //  Ejecutar las comprobaciones en segundo plano
    BudgetMonitor().runBackgroundChecks(idBudget);
    return Future.value(true); //exito
  });
}

void iosNotificationSettings() async {
  //lo mismo pero sin workmanager

  final prefs = await SharedPreferences.getInstance();
  final int? idBudget = prefs.getInt('active_budget_id');

  if (idBudget == null) return BudgetMonitor().runBackgroundChecks(idBudget!);
}
