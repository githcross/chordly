import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/models/group_membership.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';

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
              _showEditNameDialog(context);
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

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.group.name);
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
            onPressed: () {
              // TODO: Implementar cambio de nombre
              Navigator.pop(context);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Rol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GroupRole.values.map((role) {
            return RadioListTile<GroupRole>(
              title: Text(role.name.toUpperCase()),
              value: role,
              groupValue: GroupRole.values.firstWhere(
                (r) => r.name == member.role,
                orElse: () => GroupRole.member,
              ),
              onChanged: (newRole) async {
                if (newRole != null) {
                  // TODO: Implementar cambio de rol
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteDialog(
        groupId: widget.group.id,
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
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditOptionsDialog(context),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<GroupMembership>>(
          stream: ref
              .watch(firestoreServiceProvider)
              .getGroupMembers(widget.group.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = snapshot.data!;
            final admins = members
                .where((m) =>
                    m.role.toLowerCase() == GroupRole.admin.name.toLowerCase())
                .toList();
            final regularMembers = members
                .where((m) =>
                    m.role.toLowerCase() != GroupRole.admin.name.toLowerCase())
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
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: widget.group.imageUrl != null
                                ? NetworkImage(widget.group.imageUrl!)
                                : null,
                            child: widget.group.imageUrl == null
                                ? const Icon(Icons.group, size: 50)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.group.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (widget.group.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(widget.group.description),
                          ],
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
                            style: Theme.of(context).textTheme.titleLarge,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Miembros',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (widget.userRole == GroupRole.admin)
                                IconButton(
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () => _showInviteDialog(context),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Administradores
                          ...admins.map((member) => _MemberListItem(
                                name: member.displayName,
                                email: member.email,
                                role: GroupRole.admin,
                                isOnline: false,
                                canEdit: widget.userRole == GroupRole.admin,
                                onEditRole: () =>
                                    _showEditRoleDialog(context, member),
                              )),
                          // Miembros regulares
                          ...regularMembers.map((member) => _MemberListItem(
                                name: member.displayName,
                                email: member.email,
                                role: GroupRole.member,
                                isOnline: false,
                                canEdit: widget.userRole == GroupRole.admin,
                                onEditRole: () =>
                                    _showEditRoleDialog(context, member),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón de eliminar/salir
                  if (widget.userRole == GroupRole.admin)
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: Implementar eliminación
                      },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar Grupo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.all(16),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implementar salida
                      },
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Abandonar Grupo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                ],
              ),
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
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _MemberListItem extends StatelessWidget {
  final String name;
  final String email;
  final GroupRole role;
  final bool isOnline;
  final bool canEdit;
  final VoidCallback onEditRole;

  const _MemberListItem({
    required this.name,
    required this.email,
    required this.role,
    required this.isOnline,
    required this.canEdit,
    required this.onEditRole,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          const CircleAvatar(
            child: Icon(Icons.person),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
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
      title: Text(name),
      subtitle: Text(email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onEditRole,
            ),
        ],
      ),
    );
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  final String groupId;

  const _InviteDialog({required this.groupId});

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
                              await ref
                                  .read(firestoreServiceProvider)
                                  .inviteToGroup(
                                    groupId: widget.groupId,
                                    userId: user['id'],
                                    role: GroupRole.member.name,
                                  );
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Usuario invitado con éxito'),
                                  ),
                                );
                              }
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
