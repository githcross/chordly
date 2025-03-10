import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/presentation/screens/home_group_screen.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:chordly/features/groups/providers/invitations_provider.dart';
import 'package:chordly/features/groups/models/group_invitation_model.dart';
import 'package:chordly/features/profile/presentation/screens/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/core/services/version_service.dart';
import 'package:chordly/features/settings/presentation/screens/settings_screen.dart';

class GroupListItem extends StatelessWidget {
  final GroupModel group;
  final GroupRole role;
  final bool isLoading;

  const GroupListItem({
    super.key,
    required this.group,
    required this.role,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: AppTextStyles.itemTitle(context),
              ),
            ),
          ],
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Container(
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
        subtitle: Text(
          group.description,
          style: AppTextStyles.subtitle(context),
        ),
        leading: CircleAvatar(
          backgroundImage:
              group.imageUrl != null ? NetworkImage(group.imageUrl!) : null,
          child: group.imageUrl == null ? const Icon(Icons.group) : null,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeGroupScreen(
                group: group,
                userRole: role,
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await VersionService.checkAndHandleNewVersion();
      _checkDisplayName();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateOnlineStatus(false);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateOnlineStatus(false);
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      await ref.read(firestoreServiceProvider).updateUserOnlineStatus(
            user.uid,
            isOnline,
          );
    }
  }

  void _checkDisplayName() async {
    final user = ref.read(authProvider).value;
    if (user != null && user.displayName == null) {
      _showChangeDisplayNameDialog(context);
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Crear nuevo grupo',
            style: AppTextStyles.dialogTitle(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTextStyles.inputText(context),
              decoration: InputDecoration(
                labelText: 'Nombre del grupo',
                labelStyle: AppTextStyles.metadata(context),
                hintText: 'Ingresa el nombre del grupo',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: AppTextStyles.inputText(context),
              decoration: InputDecoration(
                labelText: 'Descripción',
                labelStyle: AppTextStyles.metadata(context),
                hintText: 'Ingresa una descripción',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final user = ref.read(authProvider).value;
              if (user == null) return;

              try {
                await ref.read(groupsProvider.notifier).createGroup(
                      nameController.text,
                      descriptionController.text,
                      user.uid,
                    );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showInvitationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final invitations = ref.watch(pendingInvitationsProvider);

          return AlertDialog(
            title:
                Text('Invitaciones', style: AppTextStyles.dialogTitle(context)),
            content: invitations.when(
              data: (invitations) {
                if (invitations.isEmpty) {
                  return Text(
                    'No tienes invitaciones pendientes',
                    style: AppTextStyles.subtitle(context),
                  );
                }
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: invitations.length,
                    itemBuilder: (context, index) {
                      final invitation = invitations[index];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(invitation.fromUserId)
                            .get(),
                        builder: (context, snapshot) {
                          final fromUserName = (snapshot.data?.data()
                                  as Map<String, dynamic>?)?['displayName'] ??
                              'Usuario desconocido';
                          return ListTile(
                            subtitle: Text(
                              '$fromUserName te invitó al grupo ${invitation.groupName}',
                              style: AppTextStyles.subtitle(context),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: () async {
                                    try {
                                      final user = ref.read(authProvider).value;
                                      if (user == null) return;

                                      await ref
                                          .read(firestoreServiceProvider)
                                          .respondToInvitation(
                                            invitationId: invitation.id,
                                            response: 'accepted',
                                            userId: user.uid,
                                            groupId: invitation.groupId,
                                          );
                                      if (mounted) Navigator.pop(context);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () async {
                                    try {
                                      final user = ref.read(authProvider).value;
                                      if (user == null) return;

                                      await ref
                                          .read(firestoreServiceProvider)
                                          .respondToInvitation(
                                            invitationId: invitation.id,
                                            response: 'rejected',
                                            userId: user.uid,
                                            groupId: invitation.groupId,
                                          );
                                      if (mounted) Navigator.pop(context);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  final userRoleProvider =
      StreamProvider.family<String?, String>((ref, groupId) {
    final user = ref.watch(authProvider).value;
    if (user != null) {
      return ref
          .read(firestoreServiceProvider)
          .getUserRoleInGroup(groupId, user.uid);
    }
    return Stream.value(null);
  });

  void _showProfileDialog(BuildContext context) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final displayName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perfil de Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${user.displayName ?? 'Sin nombre'}'),
            Text('Correo: ${user.email}'),
            // Agrega más detalles del perfil aquí
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () => _showChangeDisplayNameDialog(context),
            child: const Text('Cambiar Nombre'),
          ),
        ],
      ),
    );

    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
  }

  void _showChangeDisplayNameDialog(BuildContext context) async {
    final controller = TextEditingController();

    final displayName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nuevo Nombre',
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

    if (displayName != null) {
      final user = ref.read(authProvider).value;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await ref
            .read(firestoreServiceProvider)
            .updateUserDisplayNameInDocs(user.uid, displayName);
      }
      Navigator.pop(context, displayName);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<GroupInvitation>>>(
      pendingInvitationsProvider,
      (_, state) {
        if (state.hasValue && state.value != null && state.value!.isNotEmpty) {
          // Mostrar indicador de nuevas invitaciones
        } else {
          // Ocultar indicador de nuevas invitaciones
        }
      },
    );

    final filteredGroups =
        ref.watch(filteredGroupsProvider(_searchController.text));
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Chordly',
          style: AppTextStyles.appBarTitle(context),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                Consumer(
                  builder: (context, ref, child) {
                    final invitations = ref.watch(pendingInvitationsProvider);
                    return invitations.when(
                      data: (invitations) {
                        if (invitations.isEmpty) return const SizedBox();
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '${invitations.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    );
                  },
                ),
              ],
            ),
            onPressed: () => _showInvitationsDialog(context),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final isOnline = userData?['isOnline'] as bool? ?? false;

              return PopupMenuButton(
                offset: const Offset(0, 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
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
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 8),
                        Text('Mi Perfil',
                            style: AppTextStyles.subtitle(context)),
                      ],
                    ),
                    onTap: () {
                      if (user?.uid != null) {
                        Future.delayed(
                          const Duration(seconds: 0),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: user!.uid,
                                canEdit: true,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined),
                        const SizedBox(width: 8),
                        Text('Configuración',
                            style: AppTextStyles.subtitle(context)),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(seconds: 0),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Text('Acerca de',
                            style: AppTextStyles.subtitle(context)),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(seconds: 0),
                        () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Acerca de Chordly',
                                style: AppTextStyles.dialogTitle(context)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Versión: 1.1.0',
                                    style: AppTextStyles.subtitle(context)),
                                const SizedBox(height: 8),
                                Text(
                                  'Desarrollado por DevCross\n© 2025 Todos los derechos reservados',
                                  style: AppTextStyles.metadata(context),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.logout),
                        const SizedBox(width: 8),
                        Text('Salir', style: AppTextStyles.subtitle(context)),
                      ],
                    ),
                    onTap: () async {
                      await ref.read(authProvider.notifier).signOut();
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar grupos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: filteredGroups.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron grupos'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ref.watch(userRoleProvider(group.id)).when(
                          data: (role) {
                            return GroupListItem(
                              group: group,
                              role: role != null
                                  ? GroupRole.values.firstWhere(
                                      (r) => r.name == role,
                                      orElse: () => GroupRole.member,
                                    )
                                  : GroupRole.member,
                              isLoading: false,
                            );
                          },
                          loading: () => GroupListItem(
                            group: group,
                            role: GroupRole.member,
                            isLoading: true,
                          ),
                          error: (_, __) => GroupListItem(
                            group: group,
                            role: GroupRole.member,
                            isLoading: false,
                          ),
                        );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

Widget _buildAvatarWithOnlineIndicator(String? photoURL, bool isOnline) {
  return Stack(
    children: [
      CircleAvatar(
        radius: 20,
        backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
        child: photoURL == null ? const Icon(Icons.person) : null,
      ),
      if (isOnline)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
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
            ),
          ),
        ),
    ],
  );
}
