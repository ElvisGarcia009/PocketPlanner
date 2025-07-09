import 'dart:io';
import 'package:pocketplanner/services/budget_monitor.dart';
import 'package:workmanager/workmanager.dart';

class BackgroundService {
  static void setupiOSBackgroundExecution() {
    if (Platform.isIOS) {
      // 1. Registrar handler para fetch en background
      _registerBackgroundFetch();

      // 2. Programar solicitudes de background
      _scheduleBackgroundProcessing();
    }
  }

  static void _registerBackgroundFetch() {
    // Handler ejecutado por iOS periódicamente
    Workmanager().executeTask((task, inputData) async {
      await BudgetMonitor().runBackgroundChecks();
      return Future.value(true);
    });
  }

  static void _scheduleBackgroundProcessing() {
    // Solicitar a iOS tiempo de procesamiento periódico
    Workmanager().registerOneOffTask(
      "ios-bg-fetch",
      "ios-background-fetch",
      initialDelay: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
    );
  }
}
