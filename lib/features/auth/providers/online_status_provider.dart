import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/firestore_service_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

final onlineStatusProvider = StreamProvider.autoDispose<void>((ref) async* {
  final user = ref.watch(authProvider).value;
  if (user == null) return;

  // Marcar como online inmediatamente al iniciar
  await ref
      .read(firestoreServiceProvider)
      .updateUserOnlineStatus(user.uid, true);

  // Observar cambios en el estado de la app
  await for (final appState in ref.watch(appLifecycleProvider.stream)) {
    final isOnline = appState == AppLifecycleState.resumed;

    // Actualizar el estado online basado en el estado de la app
    await ref.read(firestoreServiceProvider).updateUserOnlineStatus(
          user.uid,
          isOnline,
          lastSeen: isOnline ? null : DateTime.now(),
        );
  }

  // Asegurar que se marque como offline al cerrar la app o disponer el provider
  ref.onDispose(() async {
    await ref.read(firestoreServiceProvider).updateUserOnlineStatus(
          user.uid,
          false,
          lastSeen: DateTime.now(),
        );
  });
});
