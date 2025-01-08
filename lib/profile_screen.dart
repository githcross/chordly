import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil del Usuario"),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    user.email ?? '',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
