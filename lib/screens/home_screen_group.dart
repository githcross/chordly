import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'songs_screen.dart';

class HomeScreenGroup extends StatelessWidget {
  final String groupId;
  final String groupName;

  const HomeScreenGroup({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: const Icon(
                Icons.group,
                color: Colors.white,
              ),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupProfileScreen(groupId: groupId),
                  ),
                );
              } else if (value == 'add_member') {
                _showAddMemberDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: const [
                    Icon(Icons.person, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Perfil del Grupo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_member',
                child: Row(
                  children: const [
                    Icon(Icons.person_add, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Agregar Miembro'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Card "Ir a Mis Canciones"
            Expanded(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongsScreen(groupId: groupId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: NetworkImage(
                            'https://res.cloudinary.com/djocon1g7/image/upload/v1736620306/gznwel11krkkxret6jav.avif'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text(
                          "Mis Canciones",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Card "Mis Listas"
            Expanded(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Función de listas en desarrollo')),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: NetworkImage(
                            'https://res.cloudinary.com/djocon1g7/image/upload/v1736620306/t8rojius63l1akhnlx01.avif'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text(
                          "Mis Listas",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Miembro'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Correo Electrónico',
            hintText: 'Ingrese el correo del nuevo miembro',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                _sendInvitation(email, context);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Por favor, ingrese un correo válido.')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(String email, BuildContext context) async {
    try {
      final invitation = {
        'email': email,
        'groupId': groupId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('invitations')
          .add(invitation);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación enviada exitosamente.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la invitación: $e')),
      );
    }
  }
}

class GroupProfileScreen extends StatelessWidget {
  final String groupId;

  const GroupProfileScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Grupo'),
      ),
      body: Center(
        child: Text('Pantalla del perfil del grupo con ID: $groupId'),
      ),
    );
  }
}
