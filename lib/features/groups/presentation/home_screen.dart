import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';
import 'package:chordly/models/group_model.dart';
import 'package:chordly/shared/widgets/loading_overlay.dart';
import 'package:chordly/features/groups/presentation/widgets/create_group_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Grupos'),
        actions: [
          IconButton(
            icon: const Badge(
              child: Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              // TODO: Implementar vista de notificaciones
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: groupsState.isLoading,
        child: Column(
          children: [
            _SearchBar(),
            Expanded(
              child: groupsState.when(
                data: (groups) => _GroupsList(groups: groups),
                error: (error, _) => Center(
                  child: Text('Error: ${error.toString()}'),
                ),
                loading: () => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Buscar grupos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              ref.read(groupsSearchProvider.notifier).state = '';
            },
          ),
        ),
        onChanged: (value) {
          ref.read(groupsSearchProvider.notifier).state = value;
        },
      ),
    );
  }
}

class _GroupsList extends ConsumerWidget {
  const _GroupsList({
    required this.groups,
  });

  final List<GroupModel> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groups.isEmpty) {
      return const Center(
        child: Text('No hay grupos disponibles'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _GroupCard(group: group);
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
  });

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // TODO: Navegar a la pantalla del grupo
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _GroupAvatar(imageUrl: group.image),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _RoleBadge(role: group.userRole),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({
    this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Icon(
              Icons.group,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.role,
  });

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role.toLowerCase()) {
      'admin' => Colors.red,
      'editor' => Colors.green,
      _ => Colors.blue,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
