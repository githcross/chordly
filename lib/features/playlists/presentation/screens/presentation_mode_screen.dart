import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';

class PresentationModeScreen extends StatefulWidget {
  final String playlistId;

  const PresentationModeScreen({
    Key? key,
    required this.playlistId,
  }) : super(key: key);

  @override
  State<PresentationModeScreen> createState() => _PresentationModeScreenState();
}

class _PresentationModeScreenState extends State<PresentationModeScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isFullScreen = false;
  bool _isAutoScrollEnabled = false;
  bool _isSetListVisible = false;
  PlaylistModel? _playlist;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('playlists')
          .doc(widget.playlistId)
          .get();

      if (!mounted) return;

      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _playlist = PlaylistModel(
          id: doc.id,
          name: data['name'],
          groupId: data['groupId'],
          date: (data['date'] as Timestamp).toDate(),
          createdBy: data['createdBy'],
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          notes: data['notes'] ?? '',
          songs: List<Map<String, dynamic>>.from(data['songs'])
              .map((song) => PlaylistSongItem(
                    songId: song['songId'],
                    order: song['order'],
                    transposedKey: song['transposedKey'],
                    notes: song['notes'] ?? '',
                  ))
              .toList(),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar playlist: $e')),
        );
      }
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrollEnabled = !_isAutoScrollEnabled;
    });
    // TODO: Implementar auto-scroll
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(_playlist!.name),
              leading: IconButton(
                icon: Icon(_isSetListVisible ? Icons.menu_open : Icons.menu),
                onPressed: () =>
                    setState(() => _isSetListVisible = !_isSetListVisible),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isAutoScrollEnabled ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: _toggleAutoScroll,
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => setState(() => _isFullScreen = true),
                ),
              ],
            ),
      body: Row(
        children: [
          if (!_isFullScreen && _isSetListVisible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 250,
              child: Card(
                margin: const EdgeInsets.all(8),
                child: _buildSetList(),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _playlist!.songs.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => _buildSongView(
                _playlist!.songs[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetList() {
    return ListView.builder(
      itemCount: _playlist!.songs.length,
      itemBuilder: (context, index) {
        final song = _playlist!.songs[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('songs')
              .doc(song.songId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(
                title: Text('Cargando...'),
              );
            }

            final songData = snapshot.data!.data() as Map<String, dynamic>;

            return ListTile(
              selected: index == _currentIndex,
              title: Text('${index + 1}. ${songData['title']}'),
              subtitle: Text('${songData['author']} - ${song.transposedKey}'),
              onTap: () => _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongView(PlaylistSongItem song) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('songs').doc(song.songId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final songData = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              songData['title'],
                              style: Theme.of(context).textTheme.headlineSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              songData['author'],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            song.transposedKey,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.music_note),
                            onPressed: () => _showTransposeDialog(song),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    songData['lyrics'],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTransposeDialog(PlaylistSongItem song) async {
    // TODO: Implementar diálogo de transposición
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
