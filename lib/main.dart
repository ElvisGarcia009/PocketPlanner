import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketplanner/auth/authGate.dart';
import 'package:pocketplanner/firebase_options.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:pocketplanner/services/actual_currency.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //No permite cambio de orientacion de la pantalla
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  //Estilo de la aplicacion inicializado
  await FlutterFlowTheme.initialize();
  //Conexion a firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActualCurrency>.value(value: ActualCurrency()),
        ChangeNotifierProvider<ActiveBudget>.value(value: ActiveBudget()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildLightTheme() {
    final light = LightModeThemeData();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: light.primary,
      scaffoldBackgroundColor: light.primaryBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: light.secondaryBackground,
        foregroundColor: light.primaryText,
        elevation: 0,
      ),
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: light.primaryText,
        displayColor: light.primaryText,
      ),
      colorScheme: ColorScheme.light(
        primary: light.primary,
        secondary: light.secondary,
        background: light.primaryBackground,
        surface: light.secondaryBackground,
        onPrimary: light.primaryText,
        onSecondary: light.secondaryText,
        onSurface: light.primaryText,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final dark = DarkModeThemeData();
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: dark.primary,
      scaffoldBackgroundColor: dark.primaryBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: dark.secondaryBackground,
        foregroundColor: dark.primaryText,
        elevation: 0,
      ),
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: dark.primaryText,
        displayColor: dark.primaryText,
      ),
      colorScheme: ColorScheme.dark(
        primary: dark.primary,
        secondary: dark.secondary,
        background: dark.primaryBackground,
        surface: dark.secondaryBackground,
        onPrimary: dark.primaryText,
        onSecondary: dark.secondaryText,
        onSurface: dark.primaryText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterFlowTheme(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PocketPlanner',
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: FlutterFlowTheme.themeMode,
        home: const AuthGate(),
      ),
    );
  }
}
