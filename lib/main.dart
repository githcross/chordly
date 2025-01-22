import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/config/theme/app_theme.dart';
import 'package:chordly/firebase_options.dart';
import 'package:chordly/features/auth/presentation/screens/auth_check_screen.dart';
import 'package:chordly/features/auth/providers/online_status_provider.dart';
import 'package:chordly/features/songs/services/song_purge_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ejecutar purga al inicio
  await SongPurgeService.purgeSongs();

  runApp(
    ProviderScope(
      child: Builder(
        builder: (context) {
          return Consumer(
            builder: (context, ref, child) {
              // Observar cambios en el ciclo de vida de la app
              ref.listen(
                appLifecycleProvider.select((value) => value.value),
                (previous, state) {
                  if (state != null) {
                    final isOnline = state == AppLifecycleState.resumed;
                    ref
                        .read(onlineStatusProvider.notifier)
                        .updateOnlineStatus(isOnline);
                  }
                },
              );

              return const MyApp();
            },
          );
        },
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Chordly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthCheckScreen(),
    );
  }
}
