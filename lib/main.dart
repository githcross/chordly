import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/config/theme/app_theme.dart';
import 'package:chordly/firebase_options.dart';
import 'package:chordly/features/auth/presentation/screens/auth_check_screen.dart';
import 'package:chordly/features/songs/services/song_purge_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:chordly/core/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chordly/core/presentation/screens/splash_screen.dart';
import 'package:chordly/features/auth/presentation/screens/login_screen.dart';
import 'package:chordly/features/home/presentation/screens/home_screen.dart';
import 'package:chordly/core/services/session_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Agregar variable global
DateTime _inactiveTime = DateTime.now();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final lastTermination = prefs.getInt('last_termination_time');

  if (lastTermination != null) {
    final session =
        SessionService(FirebaseFirestore.instance, FirebaseAuth.instance);
    final timeout = await session.getInactivityTimeout();
    final expiryTime = lastTermination + (timeout * 60 * 1000);

    if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
      await session.forceLogout();
    }
  }

  await _initializeDefaultSections();

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

Future<void> _initializeDefaultSections() async {
  final sectionsRef = FirebaseFirestore.instance.collection('song_sections');

  // Verificar si ya existen secciones
  final existingSections = await sectionsRef.count().get();
  if ((existingSections.count ?? 0) > 0) return;

  // Definir TODAS las secciones básicas
  final basicSections = [
    {
      'name': 'Intro',
      'emoji': '🎵',
      'description': 'Inicio instrumental o con letra opcional',
      'defaultColor': '#2196F3',
      'isAdvanced': false,
      'order': 1
    },
    {
      'name': 'Verse',
      'emoji': '📝',
      'description': 'Cuenta la historia, cambia en cada repetición',
      'defaultColor': '#4CAF50',
      'isAdvanced': false,
      'order': 2
    },
    {
      'name': 'Pre-Chorus',
      'emoji': '🚀',
      'description': 'Transición entre verso y coro, genera tensión',
      'defaultColor': '#9C27B0',
      'isAdvanced': false,
      'order': 3
    },
    {
      'name': 'Chorus',
      'emoji': '🎶',
      'description': 'Parte principal, melódica y repetitiva',
      'defaultColor': '#FF9800',
      'isAdvanced': false,
      'order': 4
    },
    {
      'name': 'Bridge',
      'emoji': '🎼',
      'description': 'Cambio melódico antes del último coro',
      'defaultColor': '#E91E63',
      'isAdvanced': false,
      'order': 5
    },
    {
      'name': 'Outro',
      'emoji': '🎸',
      'description': 'Cierre de la canción, puede ser brusco o fade-out',
      'defaultColor': '#607D8B',
      'isAdvanced': false,
      'order': 6
    }
  ];

  // Definir TODAS las secciones avanzadas
  final advancedSections = [
    {
      'name': 'Refrain',
      'emoji': '🔄',
      'description': 'Estribillo corto que se repite en cada verso',
      'defaultColor': '#8BC34A',
      'isAdvanced': true,
      'order': 7
    },
    {
      'name': 'Vamp',
      'emoji': '🔁',
      'description': 'Progresión de acordes repetida con variaciones',
      'defaultColor': '#673AB7',
      'isAdvanced': true,
      'order': 8
    },
    {
      'name': 'Breakdown',
      'emoji': '⬇️',
      'description': 'Baja de intensidad antes de volver a subir',
      'defaultColor': '#00BCD4',
      'isAdvanced': true,
      'order': 9
    },
    {
      'name': 'Build-Up',
      'emoji': '🔺',
      'description': 'Aumento progresivo de energía antes del clímax',
      'defaultColor': '#F44336',
      'isAdvanced': true,
      'order': 10
    },
    {
      'name': 'Interlude',
      'emoji': '🎤',
      'description': 'Sección instrumental o con efectos vocales',
      'defaultColor': '#9C27B0',
      'isAdvanced': true,
      'order': 11
    },
    {
      'name': 'Post-Chorus',
      'emoji': '🎶',
      'description': 'Extensión del coro con melodía pegajosa',
      'defaultColor': '#FFC107',
      'isAdvanced': true,
      'order': 12
    },
    {
      'name': 'Fade-Out',
      'emoji': '🔚',
      'description': 'Final en el que la música se desvanece gradualmente',
      'defaultColor': '#795548',
      'isAdvanced': true,
      'order': 13
    }
  ];

  // Crear batch para insertar todas las secciones
  final batch = FirebaseFirestore.instance.batch();

  for (final section in [...basicSections, ...advancedSections]) {
    final docRef = sectionsRef.doc();
    batch.set(docRef, section);
  }

  await batch.commit();
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final session = ref.read(sessionProvider);
    final prefs = await SharedPreferences.getInstance();

    print('''
    ==================================
    Cambio de estado: ${_stateToString(state)}
    Hora del evento: ${DateTime.now()}
    Usuario logueado: ${session.isUserLoggedIn}
    ==================================
    ''');

    switch (state) {
      case AppLifecycleState.resumed:
        await session.checkSessionExpiry();
        break;
      case AppLifecycleState.paused:
        await session.updateLastInteraction();
        _inactiveTime = DateTime.now();
        Timer(Duration(minutes: session.inactivityTimeout), () {
          if (DateTime.now().difference(_inactiveTime).inMinutes >=
              session.inactivityTimeout) {
            session.forceLogout();
          }
        });
        break;
      case AppLifecycleState.inactive:
        print('🔵 Estado inactive - Aplicación no enfocada');
        break;
      case AppLifecycleState.detached:
        print('🔴 Estado detached - Aplicación terminada');
        await prefs.setInt(
            'last_termination_time', DateTime.now().millisecondsSinceEpoch);
        break;
      case AppLifecycleState.hidden:
        print('⚫ Estado hidden - Aplicación oculta (solo Android)');
        _inactiveTime = DateTime.now();
        Timer(Duration(minutes: session.inactivityTimeout), () {
          if (DateTime.now().difference(_inactiveTime).inMinutes >=
              session.inactivityTimeout) {
            session.forceLogout();
          }
        });
        break;
    }
  }

  String _stateToString(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.resumed => 'resumed (en primer plano)',
      AppLifecycleState.inactive => 'inactive (no enfocada)',
      AppLifecycleState.paused => 'paused (en segundo plano)',
      AppLifecycleState.detached => 'detached (destruida)',
      AppLifecycleState.hidden => 'hidden (oculta)',
      _ => 'unknown',
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Chordly',
      debugShowCheckedModeBanner: false,
      theme: themeState.themeData,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/auth_check': (context) => const AuthCheckScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
