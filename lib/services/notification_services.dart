// lib/notifications/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // IDs de canales (Android) / categorías (iOS)
  static const _channelId     = 'budget';
  static const _channelName   = 'Presupuesto';
  static const _channelDesc   = 'Alertas de gastos y ahorros';

  Future<void> init() async {
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Definimos el canal en Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ));
  }

  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // id único
      title,
      body,
      _details(),
      payload: payload,
    );
  }

  /// Programa una notificación para una fecha/hora concreta
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final tzDate = tz.TZDateTime.from(dateTime, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      _details(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'budget',
    );
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _channelId,
        ),
      );

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll()     => _plugin.cancelAll();
}

