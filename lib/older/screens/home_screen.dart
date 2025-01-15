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

  void _showInvitationsDialog(BuildContext context, User? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invitaciones Pendientes'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('invitations')
                .where('email', isEqualTo: user?.email)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return Text('No tienes invitaciones pendientes');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final invitation = snapshot.data!.docs[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('communities')
                        .doc(invitation['groupId'])
                        .get(),
                    builder: (context, groupSnapshot) {
                      if (!groupSnapshot.hasData) {
                        return ListTile(title: Text('Cargando...'));
                      }

                      final groupData =
                          groupSnapshot.data!.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(groupData['name']),
                        subtitle: Text('Te han invitado a unirte'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () => _acceptInvitation(
                                invitation.id,
                                invitation['groupId'],
                                user,
                                context,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => _rejectInvitation(
                                invitation.id,
                                context,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _acceptInvitation(String invitationId, String groupId,
      User? user, BuildContext context) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance
              .collection('invitations')
              .doc(invitationId),
          {'status': 'accepted'},
        );
        transaction.update(
          FirebaseFirestore.instance.collection('communities').doc(groupId),
          {
            'members': FieldValue.arrayUnion([
              {
                'userId': user.uid,
                'email': user.email,
                'name': user.displayName,
                'photoURL': user.photoURL,
              }
            ])
          },
        );
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar la invitación: $e')),
      );
    }
  }

  Future<void> _rejectInvitation(
      String invitationId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitationId)
          .update({'status': 'rejected'});
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar la invitación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text("Chordly", style: kTitleTextStyle),
          actions: [
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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invitations')
                  .where('email', isEqualTo: user?.email)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                int invitationCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;

                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications,
                          size: kIconSize, color: kIconColor),
                      tooltip: 'Invitaciones',
                      onPressed: () {
                        _showInvitationsDialog(context, user);
                      },
                    ),
                    if (invitationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$invitationCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
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
      ),
    );
  }
}
