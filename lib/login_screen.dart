import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class LoginScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login con Google"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            User? user = await _authService.signInWithGoogle();
            if (user != null) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar sesión')));
            }
          },
          child: Text("Iniciar sesión con Google"),
        ),
      ),
    );
  }
}
