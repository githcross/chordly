import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/shared/widgets/error_dialog.dart';
import 'package:chordly/shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      next?.whenOrNull(
        error: (error, _) {
          showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              message: error.toString(),
            ),
          );
        },
      );
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                Text(
                  'Chordly',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 48),
                _GoogleSignInButton(
                  onPressed: () =>
                      ref.read(authProvider.notifier).signInWithGoogle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/google_logo.png',
            height: 24,
          ),
          const SizedBox(width: 16),
          const Text('Iniciar sesión con Google'),
        ],
      ),
    );
  }
}
