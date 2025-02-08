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
import 'package:image_picker/image_picker.dart';
import 'package:chordly/features/groups/presentation/screens/add_video_screen.dart';
import 'package:video_player/video_player.dart';

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
    return StreamBuilder<QuerySnapshot>(
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

        return _TikTokStyleVideoList(videos: videos);
      },
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVideoScreen(groupId: widget.group.id),
            ),
          );
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

class _TikTokStyleVideoList extends StatefulWidget {
  final List<QueryDocumentSnapshot> videos;

  const _TikTokStyleVideoList({required this.videos});

  @override
  __TikTokStyleVideoListState createState() => __TikTokStyleVideoListState();
}

class __TikTokStyleVideoListState extends State<_TikTokStyleVideoList> {
  late PageController _pageController;
  late List<VideoPlayerController> _controllers = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _updateControllers();
  }

  @override
  void didUpdateWidget(covariant _TikTokStyleVideoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videos != widget.videos) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    // Dispose old controllers
    for (var controller in _controllers) {
      controller.dispose();
    }

    // Initialize new controllers
    _controllers = widget.videos.map((videoDoc) {
      final videoUrl = videoDoc['videoUrl'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        return VideoPlayerController.networkUrl(Uri.parse('invalid_url'))
          ..setLooping(true);
      }
      return VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((error) {
          print('Error initializing video: $error');
        });
    }).toList();

    // Reset page controller
    _currentPage = 0;
    if (_controllers.isNotEmpty) {
      _controllers[0].initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controllers[0].play();
        }
      });
    }
  }

  void _handlePageChanged(int page) {
    if (page < 0 || page >= _controllers.length) return;

    // Pause previous video if valid
    if (_currentPage < _controllers.length) {
      final previousController = _controllers[_currentPage];
      if (previousController.value.isInitialized &&
          previousController.value.isPlaying) {
        previousController.pause();
      }
    }

    // Play new video if valid
    _currentPage = page;
    final currentController = _controllers[page];
    if (currentController.value.isInitialized &&
        !currentController.value.isPlaying) {
      currentController.play();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.videos.isEmpty
        ? Center(
            child: Text(
              'No hay videos disponibles',
              style: AppTextStyles.subtitle(context),
            ),
          )
        : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: _handlePageChanged,
            itemBuilder: (context, index) {
              if (index >= _controllers.length) return const SizedBox.shrink();

              final videoData =
                  widget.videos[index].data() as Map<String, dynamic>;
              final controller = _controllers[index];

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (controller.value.isInitialized &&
                      controller.value.isBuffering)
                    const Center(child: CircularProgressIndicator())
                  else if (controller.value.isInitialized)
                    AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                  _VideoOverlay(videoData: videoData),
                ],
              );
            },
          );
  }
}

class _VideoOverlay extends StatelessWidget {
  final Map<String, dynamic> videoData;

  const _VideoOverlay({required this.videoData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            videoData['title'] ?? 'Sin título',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            videoData['description'] ?? '',
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.thumb_up, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${videoData['likes'] ?? 0}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${videoData['views'] ?? 0}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
