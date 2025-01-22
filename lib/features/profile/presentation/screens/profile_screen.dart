import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chordly/core/services/cloudinary_service.dart';
import 'package:chordly/features/groups/providers/firestore_service_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/core/theme/text_styles.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool canEdit;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.canEdit = true,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _biography;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc =
        await ref.read(firestoreServiceProvider).getUserById(widget.userId);
    final userData = userDoc.data() as Map<String, dynamic>?;
    setState(() {
      _biography = userData?['biography'] as String?;
    });
  }

  Future<void> _updateBiography(String newBiography) async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      await ref
          .read(firestoreServiceProvider)
          .updateUserBiography(user.uid, newBiography);
      setState(() {
        _biography = newBiography;
      });
    }
  }

  Future<void> _updateProfilePicture() async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      final imagePicker = ImagePicker();
      final pickedFile =
          await imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final downloadURL =
            await CloudinaryService.uploadImage(file, 'profile_pictures');

        await user.updatePhotoURL(downloadURL);
        await ref
            .read(firestoreServiceProvider)
            .updateUserProfilePicture(user.uid, downloadURL);

        ref.invalidate(authProvider);
      }
    }
  }

  Future<void> _updateDisplayName(String newDisplayName) async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      await user.updateDisplayName(newDisplayName);
      await ref
          .read(firestoreServiceProvider)
          .updateUserDisplayNameInDocs(user.uid, newDisplayName);
      ref.invalidate(authProvider);
    }
  }

  void _showEditBiographyDialog() async {
    final controller = TextEditingController(text: _biography);

    final newBiography = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Biografía'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Biografía',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newBiography != null) {
      await _updateBiography(newBiography);
    }
  }

  void _showEditDisplayNameDialog() async {
    final controller =
        TextEditingController(text: ref.read(authProvider).value?.displayName);

    final newDisplayName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newDisplayName != null) {
      await _updateDisplayName(newDisplayName);
    }
  }

  Widget _buildEditableField({
    required Widget child,
    required VoidCallback onEdit,
  }) {
    return widget.canEdit
        ? Row(
            children: [
              Expanded(child: child),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            ],
          )
        : child;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final isCurrentUser = currentUser?.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditDisplayNameDialog,
            ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.read(firestoreServiceProvider).getUserById(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final displayName = userData?['displayName'] as String?;
          final email = userData?['email'] as String?;
          final photoURL = userData?['profilePicture'] as String?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          photoURL != null ? NetworkImage(photoURL) : null,
                      child: photoURL == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    if (isCurrentUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _updateProfilePicture,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  displayName ?? 'Sin nombre',
                  style: AppTextStyles.sectionTitle(context),
                ),
              ),
              if (isCurrentUser)
                Center(
                  child: TextButton(
                    onPressed: _showEditDisplayNameDialog,
                    child: const Text('Editar nombre'),
                  ),
                ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                  'Biografía',
                  style: AppTextStyles.itemTitle(context),
                ),
                subtitle: Text(
                  _biography ?? 'Sin biografía',
                  style: AppTextStyles.subtitle(context),
                ),
                trailing: isCurrentUser
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _showEditBiographyDialog,
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Correo electrónico'),
                subtitle: Text(email ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Verificado'),
                subtitle:
                    Text(currentUser?.emailVerified == true ? 'Sí' : 'No'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha de creación'),
                subtitle:
                    Text(currentUser?.metadata.creationTime?.toString() ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Último inicio de sesión'),
                subtitle: Text(
                    currentUser?.metadata.lastSignInTime?.toString() ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }
}
