import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart'; // Botón reutilizable
import '../utils/constants.dart'; // Importando las constantes

class LoginScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryColor,
              kSecondaryColor
            ], // Usando las constantes de color
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note,
                    size: 100,
                    color: kWhiteTextColor, // Usando el color blanco definido
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Bienvenido a Chordly",
                    style: kTextStyle, // Usando el estilo de texto constante
                  ),
                  SizedBox(height: 40),
                  CustomButton(
                    onPressed: () async {
                      User? user = await _authService.signInWithGoogle();
                      if (user != null) {
                        Navigator.pushReplacementNamed(context, '/home');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al iniciar sesión')),
                        );
                      }
                    },
                    text: 'Iniciar sesión con Google',
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16.0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '@devcroos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white
                        .withOpacity(0.7), // Opacidad para hacerlo sutil
                    fontWeight: FontWeight.w300, // Ligero
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
