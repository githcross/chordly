// Archivo: lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart'; // Importando las constantes

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil del Usuario", style: kTitleTextStyle),
      ),
      body: Center(
        child: user != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user.photoURL ?? ''),
                  ),
                  SizedBox(height: 10),
                  Text(
                    user.displayName ?? 'Usuario',
                    style: kTitleTextStyle,
                  ),
                  SizedBox(height: 5),
                  Text(
                    user.email ?? '',
                    style: kSubTitleTextStyle,
                  ),
                ],
              )
            : Text(
                "No se encontraron datos del usuario",
                style: TextStyle(fontSize: 18),
              ),
      ),
    );
  }
}
