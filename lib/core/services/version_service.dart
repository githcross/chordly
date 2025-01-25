import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VersionService {
  static const String _versionKey = 'app_version';
  static const String currentVersion =
      '1.0.0'; // Mantener sincronizado con pubspec.yaml

  static Future<void> checkAndHandleNewVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString(_versionKey);

    if (storedVersion == null || storedVersion != currentVersion) {
      await _handleNewVersion();
      await prefs.setString(_versionKey, currentVersion);
    }
  }

  static Future<void> _handleNewVersion() async {
    // 1. Limpiar caché
    await DefaultCacheManager().emptyCache();

    // 2. Limpiar archivos temporales
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
      await tempDir.create();
    }

    // 3. Limpiar archivos de la aplicación que no sean esenciales
    final appDir = await getApplicationDocumentsDirectory();
    final contents = await appDir.list().toList();
    for (var entity in contents) {
      if (entity is File && entity.path.contains('backup')) {
        await entity.delete();
      }
    }

    // 4. Cerrar sesión del usuario
    await FirebaseAuth.instance.signOut();

    // 5. Limpiar SharedPreferences excepto la versión actual
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key != _versionKey) {
        await prefs.remove(key);
      }
    }
  }

  static Future<void> cleanupOnUninstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      final appDir = await getApplicationDocumentsDirectory();
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }

      await DefaultCacheManager().emptyCache();
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
}
