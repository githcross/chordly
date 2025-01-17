import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';

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

  // Estado inicial
  controller
      .add(WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);

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

  // Observar cambios en el estado de la app
  await for (final appState in ref.watch(appLifecycleProvider.stream)) {
    final isOnline = appState == AppLifecycleState.resumed;
    await ref
        .read(firestoreServiceProvider)
        .updateUserOnlineStatus(user.uid, isOnline);
  }

  // Asegurar que se marque como offline al cerrar
  ref.onDispose(() async {
    await ref
        .read(firestoreServiceProvider)
        .updateUserOnlineStatus(user.uid, false);
  });
});
