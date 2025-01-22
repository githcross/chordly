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
import 'package:intl/intl.dart';
import 'package:chordly/features/auth/providers/online_status_provider.dart';

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
  late Stream<Map<String, dynamic>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _setupCombinedStream();
  }

  void _setupCombinedStream() {
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();

    _combinedStream = userStream.map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('No se encontró el perfil');
      }
      return snapshot.data() as Map<String, dynamic>;
    });
  }

  Future<void> _updateBiography(String newBiography) async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      await ref
          .read(firestoreServiceProvider)
          .updateUserBiography(user.uid, newBiography);
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
      try {
        await user.updateDisplayName(newDisplayName);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'displayName': newDisplayName,
        });

        await ref
            .read(firestoreServiceProvider)
            .updateUserDisplayNameInDocs(user.uid, newDisplayName);

        ref.invalidate(authProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar nombre: $e')),
          );
        }
      }
    }
  }

  void _showEditBiographyDialog(String? currentBiography) async {
    final controller = TextEditingController(text: currentBiography);
    final newBiography = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Biografía'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Biografía'),
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

    if (newBiography != null && mounted) {
      await _updateBiography(newBiography);
    }
  }

  void _showEditDisplayNameDialog() async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) return;

    final controller = TextEditingController(text: currentUser.displayName);

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

    if (newDisplayName != null && mounted) {
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

  String _formatFirestoreDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    final dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Widget _buildEditableName(String? displayName, bool canEdit) {
    return InkWell(
      onTap: canEdit ? _showEditDisplayNameDialog : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName ?? 'Sin nombre',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            if (canEdit)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.edit, size: 18, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).value;
    if (authUser == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil', style: AppTextStyles.appBarTitle(context)),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userData = snapshot.data!;
          final displayName = userData['displayName'] as String?;
          final email = userData['email'] as String?;
          final photoURL = userData['profilePicture'] as String?;
          final biography = userData['biography'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (authUser.uid == widget.userId)
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
                  child: _buildEditableName(
                    displayName,
                    authUser.uid == widget.userId,
                  ),
                ),
                Center(
                  child: _buildLastSeenInfo(userData),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(
                    'Biografía',
                    style: AppTextStyles.itemTitle(context),
                  ),
                  subtitle: Text(
                    biography ?? 'Sin biografía',
                    style: AppTextStyles.subtitle(context),
                  ),
                  trailing: authUser.uid == widget.userId
                      ? IconButton(
                          icon: const Icon(Icons.edit,
                              size: 18, color: Colors.grey),
                          onPressed: () => _showEditBiographyDialog(biography),
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
                  subtitle: Text(authUser.emailVerified == true ? 'Sí' : 'No'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha de creación'),
                  subtitle: Text(_formatFirestoreDate(
                      userData['createdAt'] as Timestamp?)),
                ),
                _buildProfileInfo(userData),
                const SizedBox(height: 24),
                _buildStatistics(userData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfo(Map<String, dynamic> userData) {
    // Implementation of _buildProfileInfo method
    // This method should return a Widget
    return Container(); // Placeholder return, actual implementation needed
  }

  Widget _buildStatistics(Map<String, dynamic> userData) {
    // Implementation of _buildStatistics method
    // This method should return a Widget
    return Container(); // Placeholder return, actual implementation needed
  }

  Widget _buildLastSeenInfo(Map<String, dynamic> userData) {
    final isOnline = userData['isOnline'] as bool? ?? false;

    if (isOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green[400],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'En línea',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          'Última vez ${_formatFirestoreDate(userData['lastSeen'] as Timestamp?)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    // Implementation of _navigateToEditProfile method
    // This method should navigate to the edit profile screen
  }
}
