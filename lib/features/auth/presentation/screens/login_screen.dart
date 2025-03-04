import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                Icons.music_note_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
              ),
              const SizedBox(height: 24),
              Text(
                'Chordly',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gestiona tus canciones y playlists en grupo',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await _handleSignInWithGoogle();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al iniciar sesión: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión con Google'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      final userData = {
        'email': user.email,
        'displayName': user.displayName,
        'profilePicture': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
      };

      if (!docSnapshot.exists) {
        // Usuario nuevo
        await userDoc.set({
          ...userData,
          'createdAt': FieldValue.serverTimestamp(),
          'biography': '',
        });
      } else {
        // Usuario existente
        final updateData = <String, dynamic>{};
        final currentData = docSnapshot.data()!;

        // Verificar cambios en los datos
        if (user.displayName != currentData['displayName']) {
          updateData['displayName'] = user.displayName;
        }
        if (user.photoURL != currentData['profilePicture']) {
          updateData['profilePicture'] = user.photoURL;
        }

        // Actualizar en una sola operación
        await userDoc.update({
          'lastLogin': FieldValue.serverTimestamp(),
          ...updateData,
        });
      }

      print('Operación de usuario completada: ${user.uid}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_termination_time');
    } catch (e) {
      print('Error durante el login con Google: $e');
    }
  }
}
