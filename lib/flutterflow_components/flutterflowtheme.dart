import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kThemeModeKey = '__theme_mode__';
SharedPreferences? _prefs;

class FlutterFlowTheme extends InheritedWidget {
  const FlutterFlowTheme({super.key, required super.child});

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static ThemeMode get themeMode {
    final darkMode = _prefs?.getBool(kThemeModeKey);
    return darkMode == null
        ? ThemeMode.system
        : darkMode
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  static void saveThemeMode(ThemeMode mode) => mode == ThemeMode.system
      ? _prefs?.remove(kThemeModeKey)
      : _prefs?.setBool(kThemeModeKey, mode == ThemeMode.dark);

  static FlutterFlowThemeData of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? DarkModeThemeData() : LightModeThemeData();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

// ---------------------
// THEME DATA CLASSES
// ---------------------

abstract class FlutterFlowThemeData {
  // Colores principales
  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;

  // Colores de fondo y texto
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;

  // Acentos y estados
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  // Tipografía
  Typography get typography => ThemeTypography(this);
}

class LightModeThemeData extends FlutterFlowThemeData {
  LightModeThemeData() {
    primary = const Color(0xFF2797FF);
    secondary = const Color(0xFF0B67BC);
    tertiary = const Color(0xFFACC420);
    alternate = const Color(0xFF2B3743);
    primaryText = const Color(0xFFFFFFFF);
    secondaryText = const Color(0xFF919BAB);
    primaryBackground = const Color(0xFF161C24);
    secondaryBackground = const Color(0xFF212B36);
    accent1 = const Color(0x4C2797FF);
    accent2 = const Color(0x4C0B67BC);
    accent3 = const Color(0x4DACC420);
    accent4 = const Color(0xB3161C24);
    success = const Color(0xFF27AE52);
    warning = const Color(0xFFFC964D);
    error = const Color(0xFFEE4444);
    info = const Color(0xFFFFFFFF);
  }
}

class DarkModeThemeData extends FlutterFlowThemeData {
  DarkModeThemeData() {
    primary = const Color(0xFF2797FF);
    secondary = const Color(0xFF0B67BC);
    tertiary = const Color(0xFFACC420);
    alternate = const Color(0xFF2B3743);
    primaryText = const Color(0xFFFFFFFF);
    secondaryText = const Color(0xFF919BAB);
    primaryBackground = const Color(0xFF161C24);
    secondaryBackground = const Color(0xFF212B36);
    accent1 = const Color(0x4C2797FF);
    accent2 = const Color(0x4C0B67BC);
    accent3 = const Color(0x4DACC420);
    accent4 = const Color(0xB3161C24);
    success = const Color(0xFF27AE52);
    warning = const Color(0xFFFC964D);
    error = const Color(0xFFEE4444);
    info = const Color(0xFFFFFFFF);
  }
}

// ---------------------
// TYPOGRAFÍA
// ---------------------

abstract class Typography {
  TextStyle get displayLarge;
  TextStyle get displayMedium;
  TextStyle get displaySmall;
  TextStyle get headlineLarge;
  TextStyle get headlineMedium;
  TextStyle get headlineSmall;
  TextStyle get titleLarge;
  TextStyle get titleMedium;
  TextStyle get titleSmall;
  TextStyle get labelLarge;
  TextStyle get labelMedium;
  TextStyle get labelSmall;
  TextStyle get bodyLarge;
  TextStyle get bodyMedium;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  final FlutterFlowThemeData theme;
  ThemeTypography(this.theme);

  TextStyle get displayLarge => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 57,
        fontWeight: FontWeight.w400,
      );

  TextStyle get displayMedium => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 45,
        fontWeight: FontWeight.w400,
      );

  TextStyle get displaySmall => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      );

  TextStyle get headlineLarge => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 32,
        fontWeight: FontWeight.w400,
      );

  TextStyle get headlineMedium => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      );

  TextStyle get headlineSmall => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  TextStyle get titleLarge => GoogleFonts.outfit(
        color: theme.primaryText,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      );

  TextStyle get titleMedium => GoogleFonts.montserrat(
        color: theme.info,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  TextStyle get titleSmall => GoogleFonts.montserrat(
        color: theme.info,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  TextStyle get labelLarge => GoogleFonts.montserrat(
        color: theme.secondaryText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  TextStyle get labelMedium => GoogleFonts.montserrat(
        color: theme.secondaryText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  TextStyle get labelSmall => GoogleFonts.montserrat(
        color: theme.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );

  TextStyle get bodyLarge => GoogleFonts.montserrat(
        color: theme.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  TextStyle get bodyMedium => GoogleFonts.montserrat(
        color: theme.primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  TextStyle get bodySmall => GoogleFonts.montserrat(
        color: theme.primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
}

// ---------------------
// EXTENSION PARA override()
// ---------------------

extension TextStyleHelper on TextStyle {
  TextStyle override({
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = true,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
  }) =>
      useGoogleFonts
          ? GoogleFonts.getFont(
              fontFamily ?? 'Outfit',
              color: color ?? this.color,
              fontSize: fontSize ?? this.fontSize,
              fontWeight: fontWeight ?? this.fontWeight,
              letterSpacing: letterSpacing ?? this.letterSpacing,
              fontStyle: fontStyle ?? this.fontStyle,
              decoration: decoration,
              height: lineHeight,
              shadows: shadows,
            )
          : copyWith(
              fontFamily: fontFamily,
              color: color,
              fontSize: fontSize,
              letterSpacing: letterSpacing,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              decoration: decoration,
              height: lineHeight,
              shadows: shadows,
            );
}