import 'package:flutter/material.dart';

class GroupProfileScreen extends StatelessWidget {
  final String groupId;

  const GroupProfileScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Grupo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ID del grupo: $groupId',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Agregar miembro en desarrollo')),
                );
              },
              child: const Text('Agregar Miembro'),
            ),
          ],
        ),
      ),
    );
  }
}
