import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final sessionProvider = Provider<SessionService>((ref) {
  return SessionService(FirebaseFirestore.instance, FirebaseAuth.instance);
});

class SessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const _lastInteractionKey = 'last_user_interaction';
  int _inactivityTimeout = 5; // Valor por defecto

  SessionService(this._firestore, this._auth);

  bool get isUserLoggedIn => _auth.currentUser != null;

  Future<int> getInactivityTimeout() async {
    try {
      final doc =
          await _firestore.doc('app_status/config/session/current').get();
      return (doc.data()?['inactivityTimeoutMinutes'] ?? 30).toInt();
    } catch (e) {
      return 30;
    }
  }

  Future<void> updateLastInteraction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastInteractionKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> checkSessionExpiry() async {
    if (_auth.currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastInteraction = prefs.getInt(_lastInteractionKey);
    if (lastInteraction == null) return;

    final timeout = await getInactivityTimeout();
    final expiryTime = lastInteraction + (timeout * 60 * 1000);

    print('''
    === Chequeo de expiración de sesión ===
    Última interacción: ${DateTime.fromMillisecondsSinceEpoch(lastInteraction)}
    Tiempo actual: ${DateTime.now()}
    Tiempo de expiración configurado: $timeout minutos
    Expira a las: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}
    Diferencia: ${(DateTime.now().millisecondsSinceEpoch - expiryTime) / 60000} minutos
    ''');

    if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
      print('⚠️ Sesión expirada - Cerrando sesión');
      await _auth.signOut();
      await prefs.remove(_lastInteractionKey);
    } else {
      print(
          '✅ Sesión activa - Tiempo restante: ${(expiryTime - DateTime.now().millisecondsSinceEpoch) / 60000} minutos');
    }
  }

  Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await _auth.signOut();
    await prefs.remove(_lastInteractionKey);
    print('🔴 Sesión cerrada forzosamente');
  }

  int get inactivityTimeout => _inactivityTimeout;

  Future<void> initialize() async {
    _inactivityTimeout = await getInactivityTimeout();
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        await _updateUserStatus(false);
        break;
      case AppLifecycleState.resumed:
        await _updateUserStatus(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _updateUserStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
