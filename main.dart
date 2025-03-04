import 'package:flutter/material.dart';
import 'package:flutter_provider/flutter_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:your_app/services/session_service.dart';
import 'package:your_app/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionService =
      SessionService(FirebaseFirestore.instance, FirebaseAuth.instance);
  await sessionService.initialize();

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
