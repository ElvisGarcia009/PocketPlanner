import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> enableCollection() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  //Para obtener logs acerca de cuales pantallas han usado en la aplicación
  static Future<void> logTabChangeByIndex(int index) async {
    const screenNames = ['Budget', 'Statistics', 'Chatbot', 'Config'];

    if (index < 0 || index >= screenNames.length) return;

    final screenName = screenNames[index];

    try {
      await _analytics.logEvent(
        name: 'tab_changed',
        parameters: {'tab': screenName},
      );

      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: 'HomeScreen',
      );
    } catch (e) {
      print('Error al registrar Analytics: $e');
    }
  }
}
