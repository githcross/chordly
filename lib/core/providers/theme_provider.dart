import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeState {
  final String themeName;
  final ThemeData themeData;

  ThemeState({required this.themeName, required this.themeData});
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(ThemeState(themeName: 'light', themeData: _lightTheme)) {
    _loadTheme();
  }

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: '.SF Pro Text',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF007AFF),
      brightness: Brightness.light,
      primary: const Color(0xFF007AFF),
      secondary: const Color(0xFF007AFF).withOpacity(0.2),
      surface: const Color(0xFFF2F2F7),
      background: Colors.white,
      onSurface: Colors.black,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 4,
      color: Color(0xFFF2F2F7),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 34.0,
        fontWeight: FontWeight.w700,
        color: Colors.black,
        letterSpacing: -0.41,
      ),
      bodyLarge: TextStyle(
        fontSize: 17.0,
        color: Colors.black,
        height: 1.29,
      ),
      labelLarge: TextStyle(
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: Colors.black,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorScheme.fromSeed(
        seedColor: Color(0xFF007AFF),
      ).primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFF007AFF)
            : Colors.white.withOpacity(0.38),
      ),
      trackColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFF007AFF).withOpacity(0.3)
            : Colors.grey.shade200,
      ),
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: '.SF Pro Text',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF),
      brightness: Brightness.dark,
      primary: const Color(0xFF0A84FF),
      secondary: const Color(0xFF0A84FF).withOpacity(0.2),
      surface: const Color(0xFF1C1C1E),
      background: Colors.black,
      onSurface: Colors.white,
      onPrimary: Colors.white,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 34.0,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.41,
      ),
      bodyLarge: TextStyle(
        fontSize: 17.0,
        color: Colors.white,
        height: 1.29,
      ),
      labelLarge: TextStyle(
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Color(0xFF0A84FF),
        foregroundColor: Colors.white,
        textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF6B7FDB),
      foregroundColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFF0A84FF)
            : Colors.white.withOpacity(0.32),
      ),
      trackColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFF0A84FF).withOpacity(0.3)
            : Colors.grey.shade800,
      ),
    ),
  );

  static final _pinkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF69B4),
      brightness: Brightness.light,
      primary: const Color(0xFFFF69B4),
      secondary: const Color(0xFFFF69B4).withOpacity(0.2),
      surface: const Color.fromARGB(255, 255, 255, 255),
      background: Colors.white,
      onSurface: Colors.black,
      onPrimary: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 32,
        color: Colors.black,
      ),
      titleMedium: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: Colors.black,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFF69B4),
      foregroundColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFFFF1493)
            : Colors.white.withOpacity(0.38),
      ),
      trackColor: MaterialStateProperty.resolveWith<Color>(
        (states) => states.contains(MaterialState.selected)
            ? const Color(0xFFFF69B4).withOpacity(0.2)
            : Colors.grey.shade200,
      ),
    ),
    scaffoldBackgroundColor: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF69B4),
      brightness: Brightness.light,
    ).background,
    appBarTheme: AppBarTheme(
      color: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF69B4),
        brightness: Brightness.light,
      ).surface,
      titleTextStyle: TextStyle(
        color: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF69B4),
          brightness: Brightness.light,
        ).onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
    ),
  );

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme') ?? 'light';
    setTheme(themeName, saveToPrefs: false);
  }

  Future<void> setTheme(String themeName, {bool saveToPrefs = true}) async {
    if (themeName == state.themeName) return; // No cambiar si es el mismo tema

    ThemeData newTheme;
    switch (themeName) {
      case 'dark':
        newTheme = _darkTheme;
        break;
      case 'pink':
        newTheme = _pinkTheme;
        break;
      case 'light':
      default:
        newTheme = _lightTheme;
        break;
    }

    state = ThemeState(themeName: themeName, themeData: newTheme);

    if (saveToPrefs) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', themeName);
    }
  }
}
