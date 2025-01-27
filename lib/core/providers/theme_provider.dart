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
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );

  static final _pinkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.pink,
      brightness: Brightness.light,
      surface: Colors.white,
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
