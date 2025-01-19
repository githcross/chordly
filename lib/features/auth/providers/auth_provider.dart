import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/features/auth/repositories/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'auth_provider.g.dart';

@riverpod
class Auth extends _$Auth {
  late final _authRepository = AuthRepository(ref);

  @override
  Stream<User?> build() {
    return _authRepository.authStateChanges;
  }

  Future<void> signInWithGoogle() async {
    try {
      await _authRepository.signInWithGoogle();
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      final user = _authRepository.auth.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }
      }
      await _authRepository.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
