import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chordly/core/services/version_checker_service.dart';
import 'package:chordly/features/auth/presentation/screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chordly/features/auth/presentation/screens/auth_check_screen.dart';
import 'package:chordly/core/providers/update_reminder_provider.dart';
import 'package:chordly/core/services/session_service.dart';
import 'package:chordly/core/providers/update_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    print('[VERSION CHECK] Iniciando proceso de verificación de versión');
    await ref.read(sessionProvider).initialize();
    print('[VERSION CHECK] Sesión inicializada');
    try {
      final versionChecker = ref.read(versionCheckerProvider);

      // 1. Primero chequeo de mantenimiento
      print('[MAINTENANCE CHECK] Consultando estado de mantenimiento...');
      final maintenanceConfig =
          await versionChecker.getMaintenanceConfig().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print(
              '[MAINTENANCE ERROR] Timeout al obtener configuración de mantenimiento');
          return {};
        },
      );

      print(
          '[MAINTENANCE RESULT] Estado: ${maintenanceConfig['isActive'] ?? false} | Mensaje: ${maintenanceConfig['message']}');
      if (maintenanceConfig['isActive'] == true) {
        print(
            '[MAINTENANCE ALERT] Mantenimiento activo - Bloqueando aplicación');
        if (mounted) _showMaintenanceDialog(maintenanceConfig);
        return;
      }

      // 2. Si no hay mantenimiento, chequeo de versión
      print('[VERSION CHECK] Iniciando verificación de versión...');
      final packageInfo = await PackageInfo.fromPlatform();
      print(
          '[VERSION INFO] Versión actual: ${packageInfo.version} | Build: ${packageInfo.buildNumber}');

      final updateConfig = await versionChecker.getUpdateConfig().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print(
              '[VERSION ERROR] Timeout al obtener configuración de actualización');
          return {};
        },
      );

      print('[UPDATE CONFIG] Configuración obtenida: $updateConfig');

      final currentVersion = packageInfo.version;
      final latestVersion = updateConfig['version'] ?? '1.0.0';
      final isRequired = updateConfig['isRequired'] ?? false;

      print('[VERSION CHECK] Actual: $currentVersion | Última: $latestVersion');

      if (currentVersion == latestVersion) {
        print('[VERSION MATCH] Versión actual coincide, navegando...');
        if (mounted) navigateToAuth();
        return;
      }

      if (isRequired) {
        print('[REQUIRED UPDATE] Actualización obligatoria detectada');
        _showUpdateDialog(updateConfig, isRequired);
        return;
      }

      final shouldShowReminder = await _shouldShowReminder(
        (updateConfig['reminderCooldownHours'] ?? 24).toInt(),
        isRequired,
      );

      if (!shouldShowReminder) {
        print('[REMINDER] Recordatorio reciente, omitiendo diálogo');
        if (mounted) navigateToAuth();
        return;
      }

      print('[UPDATE REQUIRED] Mostrando diálogo de actualización');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateChecker(
            updateConfig: updateConfig,
            isRequired: updateConfig['isRequired'] ?? false,
            onPostpone: isRequired
                ? null
                : () {
                    print('[USER ACTION] Usuario pospuso actualización');
                    ref.read(updateReminderProvider.notifier).setLastReminder();
                    navigateToAuth();
                  },
          ),
        );
      }
    } catch (e) {
      print('[UNHANDLED ERROR] Error durante el chequeo: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
        );
      }
    }
  }

  Future<bool> _shouldShowReminder(int cooldownHours, bool isRequired) async {
    if (isRequired) {
      print('[REQUIRED UPDATE] Ignorando cooldown');
      return true;
    }

    if (cooldownHours == 0) {
      print('[REMINDER CONFIG] Mostrar siempre - cooldown: 0 horas');
      return true;
    }

    final validCooldown = cooldownHours.clamp(1, 720);

    final lastReminder =
        await ref.read(updateReminderProvider.notifier).getLastReminder();
    if (lastReminder == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastReminder);
    return difference.inHours >= validCooldown;
  }

  void navigateToAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
    );
  }

  void _showMaintenanceDialog(Map<String, dynamic> config) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Center(child: Text('Mantenimiento en curso')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              config['message'] ??
                  'Estamos realizando tareas de mantenimiento. Por favor, inténtelo nuevamente más tarde.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkVersion();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> config, bool isRequired) {
    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => UpdateChecker(
        updateConfig: config,
        isRequired: isRequired,
        onPostpone: isRequired
            ? null
            : () {
                ref.read(updateReminderProvider.notifier).setLastReminder();
                navigateToAuth();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(updateSettingsProvider);
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class UpdateChecker extends StatelessWidget {
  final Map<String, dynamic> updateConfig;
  final bool isRequired;
  final VoidCallback? onPostpone;

  const UpdateChecker({
    super.key,
    required this.updateConfig,
    required this.isRequired,
    this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !isRequired,
      child: AlertDialog(
        title: Text(isRequired
            ? 'Actualización requerida'
            : 'Nueva versión disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (updateConfig['releaseNotes'] != null)
              ...(updateConfig['releaseNotes'] as List)
                  .map((note) => Text('• $note')),
            const SizedBox(height: 16),
            Text('Versión: ${updateConfig['version']}'),
          ],
        ),
        actions: [
          if (!isRequired)
            TextButton(
              onPressed: onPostpone ?? () {},
              child: const Text('Más tarde'),
            ),
          FilledButton(
            onPressed: () => launchUrl(Uri.parse(updateConfig['downloadLink'])),
            child: const Text('Actualizar ahora'),
          ),
        ],
      ),
    );
  }
}
