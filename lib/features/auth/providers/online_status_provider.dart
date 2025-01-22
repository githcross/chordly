import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/firestore_service_provider.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final appLifecycleProvider =
    StreamProvider.autoDispose<AppLifecycleState>((ref) {
  final controller = StreamController<AppLifecycleState>();

  final observer = _AppLifecycleObserver(controller);
  final binding = WidgetsBinding.instance;
  binding.addObserver(observer);

  ref.onDispose(() {
    binding.removeObserver(observer);
    controller.close();
  });

  // Estado inicial - siempre comenzar como resumed cuando se inicia la app
  controller.add(AppLifecycleState.resumed);

  return controller.stream;
});

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final StreamController<AppLifecycleState> controller;

  _AppLifecycleObserver(this.controller);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.add(state);
  }
}

class OnlineStatusNotifier extends StateNotifier<bool> {
  OnlineStatusNotifier() : super(false);

  Future<void> updateOnlineStatus(bool isOnline) async {
    state = isOnline;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isOnline': isOnline,
          'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Manejar error silenciosamente
        print('Error updating online status: $e');
      }
    }
  }
}

final onlineStatusProvider =
    StateNotifierProvider<OnlineStatusNotifier, bool>((ref) {
  return OnlineStatusNotifier();
});
