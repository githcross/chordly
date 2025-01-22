import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/models/group_membership.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/group_members_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:chordly/core/services/cloudinary_service.dart';
import 'package:chordly/features/profile/presentation/screens/profile_screen.dart';
import 'package:chordly/core/theme/text_styles.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  final GroupRole userRole;

  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.userRole,
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  void _showEditOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Editar Grupo'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implementar edición de foto
            },
            child: const Row(
              children: [
                Icon(Icons.photo_camera),
                SizedBox(width: 16),
                Text('Cambiar foto'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showEditNameDialog(context, widget.group);
            },
            child: const Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 16),
                Text('Editar nombre'),
              ],
            ),
          ),
          if (widget.userRole == GroupRole.admin)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showEditRolesDialog(context);
              },
              child: const Row(
                children: [
                  Icon(Icons.people),
                  SizedBox(width: 16),
                  Text('Gestionar roles'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, GroupModel currentGroup) {
    final controller = TextEditingController(text: currentGroup.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del grupo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(currentGroup.id)
                    .update({'name': controller.text.trim()});
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre actualizado')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditRolesDialog(BuildContext context) {
    // TODO: Implementar diálogo de gestión de roles
  }

  void _showEditRoleDialog(BuildContext context, GroupMembership member) {
    if (member.userId != ref.read(authProvider).value?.uid) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Editar rol de ${member.displayName}',
            style: AppTextStyles.dialogTitle(context),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: GroupRole.values.map((role) {
              return ListTile(
                title: Text(
                  role.name.toUpperCase(),
                  style: AppTextStyles.itemTitle(context),
                ),
                leading: Icon(
                  role == GroupRole.admin
                      ? Icons.admin_panel_settings
                      : Icons.person,
                  color: role.color,
                ),
                selected: role.name == member.role,
                onTap: () async {
                  try {
                    await ref.read(firestoreServiceProvider).updateMemberRole(
                          groupId: widget.group.id,
                          userId: member.userId,
                          newRole: role.name,
                        );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Rol de ${member.displayName} actualizado a ${role.name.toUpperCase()}'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar rol: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              );
            }).toList(),
          ),
        ),
      );
    }
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteDialog(
        groupId: widget.group.id,
        groupName: widget.group.name,
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del grupo'),
        content: const Text(
            '¿Estás seguro que deseas salir de este grupo? Necesitarás una nueva invitación para volver a unirte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final user = ref.read(authProvider).value;
                if (user == null) return;

                await ref.read(firestoreServiceProvider).leaveGroup(
                      groupId: widget.group.id,
                      userId: user.uid,
                    );

                if (mounted) {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.of(context).popUntil(
                      (route) => route.isFirst); // Volver a home_screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Has abandonado el grupo'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al abandonar el grupo: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _showImageOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imagen del grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo imagen...')),
      );

      // Subir a Cloudinary
      final imageUrl = await CloudinaryService.uploadImage(
        File(pickedFile.path),
        'group_images',
      );

      // Actualizar URL en Firestore
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .update({
        'imageUrl': imageUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen actualizada correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error al subir imagen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar imagen: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFullImage(BuildContext context) {
    if (widget.group.imageUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen
                Hero(
                  tag: 'group-image-${widget.group.id}',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      widget.group.imageUrl!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Botón cerrar
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDescriptionDialog(
      BuildContext context, GroupModel currentGroup) {
    final controller = TextEditingController(text: currentGroup.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descripción'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Descripción del grupo',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(currentGroup.id)
                    .update({'description': controller.text.trim()});
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Descripción actualizada')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del Grupo'),
        actions: [
          if (widget.userRole == GroupRole.admin)
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Solo para Administradores'),
                    content: SingleChildScrollView(
                      // Permite desplazamiento si el contenido es largo
                      child: Text(
                        '• Opción eliminar grupo: \n  Se habilita cuando no hay más miembros en el grupo, solo un miembro administrador.\n\n'
                        '• Opción salir de grupo: \n  Se habilita cuando hay más de un miembro administrador.',
                        style: TextStyle(
                            fontSize: 16,
                            height:
                                1.5), // Ajuste del tamaño de texto y espaciado
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Cierra el diálogo
                        },
                        child: Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          // Escuchar cambios del grupo en tiempo real
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.group.id)
              .snapshots(),
          builder: (context, groupSnapshot) {
            if (groupSnapshot.hasError) {
              return Center(child: Text('Error: ${groupSnapshot.error}'));
            }

            if (!groupSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Convertir el snapshot a GroupModel
            final groupData =
                groupSnapshot.data!.data() as Map<String, dynamic>;
            final currentGroup = GroupModel.fromMap(widget.group.id, groupData);

            return Consumer(
              builder: (context, ref, child) {
                return StreamBuilder<List<GroupMembership>>(
                  stream: ref
                      .watch(firestoreServiceProvider)
                      .getGroupMembers(currentGroup.id),
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.hasError) {
                      return Center(
                          child: Text('Error: ${membersSnapshot.error}'));
                    }

                    if (!membersSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = membersSnapshot.data!;
                    final admins = members
                        .where((m) =>
                            m.role.toLowerCase() ==
                            GroupRole.admin.name.toLowerCase())
                        .toList();
                    final regularMembers = members
                        .where((m) =>
                            m.role.toLowerCase() !=
                            GroupRole.admin.name.toLowerCase())
                        .toList();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Detalles del grupo
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.userRole == GroupRole.admin) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Opciones de imagen'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.zoom_in),
                                                  title:
                                                      const Text('Ver imagen'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _showFullImage(context);
                                                  },
                                                ),
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.edit),
                                                  title: const Text(
                                                      'Cambiar imagen'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _showImageOptionsDialog(
                                                        context);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else {
                                        _showFullImage(context);
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        Hero(
                                          tag: 'group-image-${currentGroup.id}',
                                          child: CircleAvatar(
                                            radius: 50,
                                            backgroundImage:
                                                currentGroup.imageUrl != null
                                                    ? NetworkImage(
                                                        currentGroup.imageUrl!)
                                                    : null,
                                            child: currentGroup.imageUrl == null
                                                ? const Icon(Icons.group,
                                                    size: 50)
                                                : null,
                                          ),
                                        ),
                                        if (widget.userRole == GroupRole.admin)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Nombre del grupo
                                            InkWell(
                                              onTap: widget.userRole ==
                                                      GroupRole.admin
                                                  ? () => _showEditNameDialog(
                                                      context, currentGroup)
                                                  : null,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    currentGroup.name,
                                                    style: AppTextStyles
                                                        .sectionTitle(context),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  if (widget.userRole ==
                                                      GroupRole.admin)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 4),
                                                      child: Icon(
                                                        Icons.edit,
                                                        size: 16,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.5),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Descripción
                                            if (currentGroup
                                                    .description.isNotEmpty ||
                                                widget.userRole ==
                                                    GroupRole.admin)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    top: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceVariant
                                                      .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: InkWell(
                                                  onTap: widget.userRole ==
                                                          GroupRole.admin
                                                      ? () =>
                                                          _showEditDescriptionDialog(
                                                              context,
                                                              currentGroup)
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          currentGroup
                                                                  .description
                                                                  .isEmpty
                                                              ? 'Sin descripción'
                                                              : currentGroup
                                                                  .description,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: AppTextStyles
                                                              .subtitle(
                                                                  context),
                                                        ),
                                                      ),
                                                      if (widget.userRole ==
                                                          GroupRole.admin)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 4),
                                                          child: Icon(
                                                            Icons.edit,
                                                            size: 14,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurfaceVariant
                                                                .withOpacity(
                                                                    0.5),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Estadísticas
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estadísticas',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  _StatItem(
                                    icon: Icons.people,
                                    title: 'Miembros',
                                    value: members.length.toString(),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Lista de miembros
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Miembros',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      if (widget.userRole == GroupRole.admin)
                                        IconButton(
                                          icon: const Icon(Icons.person_add),
                                          onPressed: () =>
                                              _showInviteDialog(context),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Administradores
                                  ...admins.map((member) => _MemberListItem(
                                        name: member.displayName,
                                        email: member.email,
                                        role: GroupRole.admin,
                                        isOnline: member.isOnline,
                                        lastSeen: member.lastSeen,
                                        canEdit:
                                            widget.userRole == GroupRole.admin,
                                        onEditRole: () => _showEditRoleDialog(
                                            context, member),
                                        userId: member.userId,
                                        profilePicture: member.profilePicture,
                                      )),
                                  // Miembros regulares
                                  ...regularMembers.map((member) =>
                                      _MemberListItem(
                                        name: member.displayName,
                                        email: member.email,
                                        role: GroupRole.values.firstWhere(
                                          (r) => r.name == member.role,
                                          orElse: () => GroupRole.member,
                                        ),
                                        isOnline: member.isOnline,
                                        lastSeen: member.lastSeen,
                                        canEdit:
                                            widget.userRole == GroupRole.admin,
                                        onEditRole: () => _showEditRoleDialog(
                                            context, member),
                                        userId: member.userId,
                                        profilePicture: member.profilePicture,
                                      )),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botón de eliminar/salir
                          if (widget.userRole == GroupRole.admin)
                            if (admins.length > 1)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showLeaveConfirmation(context),
                                  icon: const Icon(Icons.exit_to_app),
                                  label: const Text(
                                    'Abandonar Grupo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
                                    side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withOpacity(0.5),
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                          if (members.length.toString() == 1)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: FilledButton.icon(
                                onPressed: () {
                                  // TODO: Implementar eliminación
                                  _showTopNotification(
                                      context, 'Funcion en desarrollo');
                                },
                                icon: const Icon(Icons.delete_forever),
                                label: const Text(
                                  'Eliminar Grupo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )
                          else if (widget.userRole != GroupRole.admin)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showLeaveConfirmation(context),
                                icon: const Icon(Icons.exit_to_app),
                                label: const Text(
                                  'Abandonar Grupo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.error,
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withOpacity(0.5),
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.itemTitle(context),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.metadata(context).copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MemberListItem extends ConsumerWidget {
  final String name;
  final String email;
  final GroupRole role;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool canEdit;
  final VoidCallback onEditRole;
  final String userId;
  final String? profilePicture;

  const _MemberListItem({
    required this.name,
    required this.email,
    required this.role,
    required this.isOnline,
    this.lastSeen,
    required this.canEdit,
    required this.onEditRole,
    required this.userId,
    this.profilePicture,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                profilePicture != null ? NetworkImage(profilePicture!) : null,
            backgroundColor: isOnline ? Colors.green : Colors.grey,
            child: profilePicture == null
                ? Icon(Icons.person, color: Colors.white)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        name,
        style: AppTextStyles.itemTitle(context),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            email,
            style: AppTextStyles.subtitle(context),
          ),
          if (!isOnline && lastSeen != null)
            Text(
              _getLastSeenText(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: role.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: role.color),
        ),
        child: Text(
          role.name.toUpperCase(),
          style: TextStyle(
            color: role.color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () {
        final currentUser = ref.read(authProvider).value;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: userId,
              canEdit: currentUser?.uid == userId,
            ),
          ),
        );
      },
      onLongPress: canEdit ? onEditRole : null,
    );
  }

  String _getLastSeenText() {
    if (lastSeen == null) return '';
    final difference = DateTime.now().difference(lastSeen!);
    if (difference.inMinutes < 1) return 'Hace un momento';
    if (difference.inHours < 1) return 'Hace ${difference.inMinutes} minutos';
    if (difference.inDays < 1) return 'Hace ${difference.inHours} horas';
    return 'Hace ${difference.inDays} días';
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const _InviteDialog({
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar Miembro'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (searchController.text.isNotEmpty)
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref
                      .read(firestoreServiceProvider)
                      .searchUsers(searchController.text),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No se encontraron usuarios');
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final user = snapshot.data![index];

                        // Verificación adicional de miembros del grupo
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('groups')
                              .doc(widget.groupId)
                              .collection('memberships')
                              .doc(user['id'])
                              .get(),
                          builder: (context, membershipSnapshot) {
                            if (membershipSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            // Si el usuario ya es miembro, no mostrar en la lista
                            if (membershipSnapshot.hasData &&
                                membershipSnapshot.data!.exists) {
                              return const SizedBox.shrink();
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['profilePicture'] != null
                                    ? NetworkImage(user['profilePicture'])
                                    : null,
                                child: user['profilePicture'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user['displayName'] ?? user['email']),
                              subtitle: Text(user['email']),
                              onTap: () async {
                                try {
                                  final currentUser =
                                      ref.read(authProvider).value;
                                  if (currentUser == null) return;

                                  await ref
                                      .read(firestoreServiceProvider)
                                      .sendGroupInvitation(
                                        groupId: widget.groupId,
                                        groupName: widget.groupName,
                                        fromUserId: currentUser.uid,
                                        toUserId: user['id'],
                                      );
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showTopNotification(
                                        context, 'Invitación enviada');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    _showTopNotification(context, e.toString());
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class TopNotification extends StatelessWidget {
  final String message;
  final Color backgroundColor;

  const TopNotification({
    Key? key,
    required this.message,
    this.backgroundColor = const Color.fromARGB(255, 207, 24, 24),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50, // Ajusta según sea necesario
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: AppTextStyles.buttonText(context).copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

void _showTopNotification(BuildContext context, String message) {
  OverlayEntry? overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => TopNotification(message: message),
  );

  Overlay.of(context).insert(overlayEntry);

  // Desaparecer después de 3 segundos
  Future.delayed(const Duration(seconds: 3), () {
    overlayEntry?.remove();
  });
}
