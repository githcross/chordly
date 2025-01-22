import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/firestore_service_provider.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';

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
  final FirestoreService _firestoreService;
  final String _userId;

  OnlineStatusNotifier(this._firestoreService, this._userId) : super(true) {
    updateOnlineStatus(true);
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    state = isOnline;
    await _firestoreService.updateUserOnlineStatus(_userId, isOnline);
  }

  @override
  void dispose() {
    updateOnlineStatus(false);
    super.dispose();
  }
}

final onlineStatusProvider =
    StateNotifierProvider<OnlineStatusNotifier, bool>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) throw Exception('Usuario no autenticado');

  return OnlineStatusNotifier(
    ref.read(firestoreServiceProvider),
    user.uid,
  );
});
