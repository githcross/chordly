import 'package:flutter/material.dart';

extension CustomColors on ColorScheme {
  Color get introColor => const Color(0xFF90CAF9);
  Color get verseColor => const Color(0xFFA5D6A7);
  Color get chorusColor => const Color(0xFFFFCC80);
  Color get bridgeColor => const Color(0xFFCE93D8);
  Color get outroColor => const Color(0xFF80DEEA);
}

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    primary: Colors.blueGrey.shade800, // Color principal azul-negro
    secondary: Colors.blueGrey.shade600, // Color secundario para acordes
    background: Colors.white, // Fondo claro
    onPrimary: Colors.white, // Texto sobre color primario
  ),
  // ... resto de la configuración del tema
);
