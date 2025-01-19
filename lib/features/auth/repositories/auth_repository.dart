import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref ref;

  AuthRepository(this.ref);

  FirebaseAuth get auth => _auth;

  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) throw Exception('Google sign in aborted');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Aquí se crea o actualiza el documento del usuario
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      // Actualizar estado online al iniciar sesión
      if (userCredential.user != null) {
        await ref.read(firestoreServiceProvider).updateUserOnlineStatus(
              userCredential.user!.uid,
              true,
            );
      }

      return userCredential;
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> _createUserDocument(User user) async {
    final userData = {
      'email': user.email,
      'displayName': user.displayName ?? user.email?.split('@')[0],
      'profilePicture': user.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
      'groups': [],
    };

    // Esta línea crea o actualiza el documento del usuario
    await ref
        .read(firestoreServiceProvider)
        .createOrUpdateUser(user.uid, userData);
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Actualizar estado offline antes de cerrar sesión
      await ref.read(firestoreServiceProvider).updateUserOnlineStatus(
            user.uid,
            false,
          );
    }

    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
