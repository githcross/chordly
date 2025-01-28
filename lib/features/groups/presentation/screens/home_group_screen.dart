import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/presentation/screens/edit_group_screen.dart';
import 'package:chordly/features/groups/presentation/screens/group_info_screen.dart';
import 'package:chordly/features/songs/presentation/screens/add_song_screen.dart';
import 'package:chordly/features/songs/presentation/screens/list_songs_screen.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:chordly/features/playlists/presentation/screens/playlist_screen.dart';
import 'package:chordly/features/playlists/presentation/screens/select_songs_screen.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/songs/presentation/delegates/song_search_delegate.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';
import 'package:chordly/features/songs/presentation/screens/deleted_songs_screen.dart';

class HomeGroupScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  final GroupRole userRole;

  const HomeGroupScreen({
    super.key,
    required this.group,
    required this.userRole,
  });

  @override
  ConsumerState<HomeGroupScreen> createState() => _HomeGroupScreenState();
}

class _HomeGroupScreenState extends ConsumerState<HomeGroupScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ListSongsScreenState> _songsKey = GlobalKey();

  void _showTagFilter() async {
    final songsState = _songsKey.currentState;
    if (songsState == null) return;

    final allTags = await FirebaseFirestore.instance
        .collection('tags')
        .doc('default')
        .get();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por etiquetas'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (allTags.data()?['tags'] as List<dynamic>? ?? [])
                .map((tag) => FilterChip(
                      label: Text(tag),
                      selected: songsState.selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            songsState.selectedTags.add(tag);
                          } else {
                            songsState.selectedTags.remove(tag);
                          }
                        });
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                songsState.selectedTags.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _toggleSortOrder() {
    final songsState = _songsKey.currentState;
    if (songsState != null) {
      setState(() {
        songsState.ascendingOrder = !songsState.ascendingOrder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.group.name,
          style: AppTextStyles.appBarTitle(context),
        ),
        actions: [
          ..._buildActionsForCurrentTab(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfoScreen(
                      group: widget.group,
                      userRole: widget.userRole,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'group-image-${widget.group.id}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage: widget.group.imageUrl != null
                      ? NetworkImage(widget.group.imageUrl!)
                      : null,
                  child: widget.group.imageUrl == null
                      ? Icon(
                          Icons.group,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.video_collection),
            label: 'Videos',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Canciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  List<Widget> _buildActionsForCurrentTab() {
    switch (_selectedIndex) {
      case 0: // Videos
        return [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar videos',
            onPressed: () {
              // TODO: Implementar búsqueda de videos
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar videos',
            onPressed: () {
              // TODO: Implementar filtro de videos
            },
          ),
        ];
      case 1: // Canciones
        final songsState = _songsKey.currentState;
        return [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar canciones',
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(
                  groupId: widget.group.id,
                  onSongSelected: (songId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailsScreen(
                          songId: songId,
                          groupId: widget.group.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: songsState?.selectedTags.isNotEmpty ?? false,
              label: Text((songsState?.selectedTags.length ?? 0).toString()),
              child: const Icon(Icons.tag),
            ),
            tooltip: 'Filtrar por tags',
            onPressed: _showTagFilter,
          ),
          IconButton(
            icon: Icon(
              songsState?.ascendingOrder ?? true
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            tooltip: 'Ordenar',
            onPressed: _toggleSortOrder,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  if (songsState != null) {
                    songsState.shareSongs([]);
                  }
                  break;
                case 'deleted':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeletedSongsScreen(
                        group: widget.group,
                      ),
                    ),
                  );
                  break;
                case 'backup':
                  if (songsState != null) {
                    songsState.showBackupDialog();
                  }
                  break;
                case 'restore':
                  if (songsState != null) {
                    songsState.showRestoreDialog();
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Exportar canciones'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'deleted',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Ver eliminadas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup),
                    SizedBox(width: 8),
                    Text('Crear copia de seguridad'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore),
                    SizedBox(width: 8),
                    Text('Restaurar copia'),
                  ],
                ),
              ),
            ],
          ),
        ];
      case 2: // Playlists
        return [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar playlists',
            onPressed: () {
              // TODO: Implementar búsqueda de playlists
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onPressed: () {
              // TODO: Implementar ordenamiento de playlists
            },
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildVideosTab();
      case 1:
        return ListSongsScreen(
          key: _songsKey,
          group: widget.group,
        );
      case 2:
        return _buildPlaylistsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVideosTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.group.id)
                .collection('videos')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final videos = snapshot.data!.docs;
              if (videos.isEmpty) {
                return Center(
                  child: Text(
                    'No hay videos publicados',
                    style: AppTextStyles.subtitle(context),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 9 / 16,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index].data();
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          video['thumbnailUrl'] ?? '',
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              video['title'] ?? 'Sin título',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // TODO: Implementar visualización del video
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongsTab() {
    return ListSongsScreen(group: widget.group);
  }

  Widget _buildPlaylistsTab() {
    return PlaylistScreen(groupId: widget.group.id);
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedIndex == 0 && widget.userRole == GroupRole.admin) {
      return FloatingActionButton(
        onPressed: () {
          // TODO: Implementar subida de videos
        },
        child: const Icon(Icons.video_call),
      );
    } else if (_selectedIndex == 1) {
      return FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddSongScreen(groupId: widget.group.id),
          ),
        ),
        child: const Icon(Icons.add),
      );
    } else if (_selectedIndex == 2) {
      return FloatingActionButton(
        onPressed: () => _createPlaylist(context),
        child: const Icon(Icons.playlist_add),
      );
    }
    return null;
  }

  void _createPlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSongsScreen(
          groupId: widget.group.id,
        ),
      ),
    );
  }
}

class _HorizontalCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _HorizontalCategoryCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.itemTitle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca para ver detalles',
                      style: AppTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
