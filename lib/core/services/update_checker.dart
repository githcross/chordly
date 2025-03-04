import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:app_status/providers/update_provider.dart';

class UpdateChecker {
  final Ref ref;

  UpdateChecker(this.ref);

  Future<void> checkForUpdates(BuildContext context) async {
    print(
        '[UPDATE CHECK] Iniciando proceso de verificación de actualizaciones');

    final settings = await ref.read(updateSettingsProvider.future);
    print('[REMOTE SETTINGS] Configuración remota: $settings');

    final currentVersion = await getCurrentVersion();
    final latestVersion = settings['latestVersion'] ?? '1.0.0';
    final cooldownHours = settings['reminderCooldownHours'] ?? 1;

    print('[VERSION COMPARE] Actual: $currentVersion | Última: $latestVersion');
    print('[COOLDOWN] Horas de espera: $cooldownHours');

    if (currentVersion != latestVersion) {
      print('[UPDATE NEEDED] Nueva versión disponible');
      // Mostrar diálogo...
    } else {
      print('[VERSION OK] La aplicación está actualizada');
    }
  }
}
