import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/config/theme/app_theme.dart';
import 'package:chordly/firebase_options.dart';
import 'package:chordly/features/auth/presentation/screens/auth_check_screen.dart';
import 'package:chordly/features/songs/services/song_purge_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:chordly/core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ejecutar purga al inicio
  await SongPurgeService.purgeSongs();

  // Agregar esta línea antes de runApp
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Chordly',
      debugShowCheckedModeBanner: false,
      theme: themeState.themeData,
      home: const AuthCheckScreen(),
    );
  }
}
