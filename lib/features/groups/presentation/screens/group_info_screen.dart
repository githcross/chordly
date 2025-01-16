import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/models/group_model.dart';

class GroupInfoScreen extends ConsumerWidget {
  final GroupModel group;
  final GroupRole userRole;

  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.userRole,
  });

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
          if (userRole == GroupRole.admin)
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
    final controller = TextEditingController(text: group.name);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del Grupo'),
        actions: [
          if (userRole == GroupRole.admin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditOptionsDialog(context),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                        backgroundImage: group.imageUrl != null
                            ? NetworkImage(group.imageUrl!) as ImageProvider
                            : const AssetImage(
                                'assets/images/group_placeholder.png'),
                        child: group.imageUrl == null
                            ? const Icon(Icons.group, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        group.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _StatItem(
                        icon: Icons.people,
                        title: 'Miembros',
                        value: '0', // TODO: Implementar contador real
                      ),
                      const Divider(),
                      _StatItem(
                        icon: Icons.music_note,
                        title: 'Canciones',
                        value: '0',
                      ),
                      const Divider(),
                      _StatItem(
                        icon: Icons.queue_music,
                        title: 'Playlists',
                        value: '0',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lista de miembros
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Miembros',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (userRole == GroupRole.admin)
                            IconButton(
                              icon: const Icon(Icons.person_add),
                              onPressed: () {
                                // TODO: Implementar invitación de miembros
                              },
                            ),
                        ],
                      ),
                    ),
                    // Lista de miembros (ejemplo)
                    _MemberListItem(
                      name: 'Usuario Ejemplo',
                      email: 'usuario@ejemplo.com',
                      role: GroupRole.admin,
                      isOnline: true,
                      canEdit: userRole == GroupRole.admin,
                      onEditRole: () {
                        // TODO: Implementar edición de rol
                      },
                    ),
                    const Divider(),
                    _MemberListItem(
                      name: 'Otro Usuario',
                      email: 'otro@ejemplo.com',
                      role: GroupRole.member,
                      isOnline: false,
                      canEdit: userRole == GroupRole.admin,
                      onEditRole: () {
                        // TODO: Implementar edición de rol
                      },
                    ),
                  ],
                ),
              ),

              // Acciones
              if (userRole == GroupRole.admin)
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
