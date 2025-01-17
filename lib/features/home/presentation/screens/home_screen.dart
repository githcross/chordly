import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/presentation/screens/home_group_screen.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:chordly/features/groups/providers/invitations_provider.dart';

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
            Expanded(child: Text(group.name)),
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
        subtitle: Text(group.description),
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear nuevo grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ingresa el nombre del grupo',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
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
            title: const Text('Invitaciones'),
            content: invitations.when(
              data: (invitations) {
                if (invitations.isEmpty) {
                  return const Text('No tienes invitaciones pendientes');
                }

                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: invitations.length,
                    itemBuilder: (context, index) {
                      final invitation = invitations[index];
                      return ListTile(
                        title: Text(invitation.groupName),
                        subtitle: Text('De: ${invitation.fromUserName}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              color: Colors.green,
                              onPressed: () async {
                                await ref
                                    .read(firestoreServiceProvider)
                                    .respondToInvitation(
                                      invitationId: invitation.id,
                                      response: 'accepted',
                                      userId: invitation.toUserId,
                                      groupId: invitation.groupId,
                                    );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: Colors.red,
                              onPressed: () async {
                                await ref
                                    .read(firestoreServiceProvider)
                                    .respondToInvitation(
                                      invitationId: invitation.id,
                                      response: 'rejected',
                                      userId: invitation.toUserId,
                                      groupId: invitation.groupId,
                                    );
                              },
                            ),
                          ],
                        ),
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

  @override
  Widget build(BuildContext context) {
    final filteredGroups =
        ref.watch(filteredGroupsProvider(_searchController.text));
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Grupos'),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
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
                    return FutureBuilder<String?>(
                      future: ref
                          .read(firestoreServiceProvider)
                          .getUserRoleInGroup(group.id, user?.uid ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return GroupListItem(
                            group: group,
                            role: GroupRole.member,
                            isLoading: true,
                          );
                        }

                        final role = snapshot.data != null
                            ? GroupRole.values.firstWhere(
                                (r) => r.name == snapshot.data,
                                orElse: () => GroupRole.member,
                              )
                            : GroupRole.member;

                        return GroupListItem(
                          group: group,
                          role: role,
                          isLoading: false,
                        );
                      },
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
