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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
