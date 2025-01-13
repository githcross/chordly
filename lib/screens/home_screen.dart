import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/constants.dart';
import 'home_screen_group.dart';

class HomeScreen extends StatelessWidget {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  void _showCreateGroupDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Crear Nuevo Grupo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Grupo',
                    hintText: 'Ingrese el nombre del grupo',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Descripción opcional',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => _createGroup(context, user),
              child: Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGroup(BuildContext context, User user) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El nombre del grupo es requerido')),
      );
      return;
    }

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('communities').add({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'ownerId': user.uid,
        'ownerInfo': {
          'name': user.displayName ?? 'Usuario sin nombre',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
        },
        'members': [
          {
            'userId': user.uid,
            'role': 'admin',
            'name': user.displayName ?? 'Usuario sin nombre',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'playlists': [],
        'songs': []
      });

      // Limpiar los controladores
      _nameController.clear();
      _descriptionController.clear();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grupo creado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el grupo: $e')),
      );
    }
  }

  Widget _buildGroupsList(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .where('members', arrayContains: {
        'userId': user.uid,
        'role': 'admin',
        'name': user.displayName ?? 'Usuario sin nombre',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
      }).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No perteneces a ningún grupo',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index].data() as Map<String, dynamic>;
            final ownerInfo = group['ownerInfo'] as Map<String, dynamic>;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(ownerInfo['photoURL'] ?? ''),
                ),
                title: Text(group['name']),
                subtitle: Text(group['description'] ?? 'Sin descripción'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreenGroup(
                        groupId: groups[index].id,
                        groupName: group['name'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Chordly", style: kTitleTextStyle),
        actions: [
          // Icono para crear nuevo grupo
          IconButton(
            icon: Icon(Icons.group_add, size: kIconSize, color: kIconColor),
            tooltip: 'Crear Grupo',
            onPressed: () {
              if (user != null) {
                _showCreateGroupDialog(context, user);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Debes iniciar sesión para crear un grupo')),
                );
              }
            },
          ),
          // Icono de notificaciones
          IconButton(
            icon: Icon(Icons.notifications, size: kIconSize, color: kIconColor),
            tooltip: 'Notificaciones',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Función de notificaciones en desarrollo')),
              );
            },
          ),
          // Menú de perfil
          if (user != null)
            PopupMenuButton(
              icon: CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(user.photoURL ?? ''),
              ),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Mi Perfil'),
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Cerrar Sesión'),
                    onTap: () async {
                      await _authService.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis Grupos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: user != null
                  ? _buildGroupsList(user)
                  : Center(
                      child: Text('Inicia sesión para ver tus grupos'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
