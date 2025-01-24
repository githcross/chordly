import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeleprompterScreen extends StatefulWidget {
  final String title;
  final String lyrics;
  final List<String>? playlistSongs;
  final int? currentIndex;

  const TeleprompterScreen({
    Key? key,
    required this.title,
    required this.lyrics,
    this.playlistSongs,
    this.currentIndex,
  }) : super(key: key);

  @override
  State<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends State<TeleprompterScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  double _scrollSpeed = 30.0; // Pixeles por segundo
  Timer? _scrollTimer;
  bool _isPlaylistVisible = false;
  late int _currentSongIndex;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.currentIndex ?? 0;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleScroll() {
    setState(() {
      _isScrolling = !_isScrolling;
      if (_isScrolling) {
        _startScroll();
      } else {
        _scrollTimer?.cancel();
      }
    });
  }

  void _startScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollTimer?.cancel();
          setState(() => _isScrolling = false);
          return;
        }
        _scrollController.jumpTo(currentScroll + _scrollSpeed / 20);
      }
    });
  }

  void _adjustSpeed(double change) {
    setState(() {
      _scrollSpeed = (_scrollSpeed + change).clamp(10.0, 100.0);
    });
  }

  void _resetScroll() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _isScrolling = false);
    _scrollTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.playlistSongs != null)
            IconButton(
              icon: Icon(
                _isPlaylistVisible ? Icons.playlist_play : Icons.queue_music,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isPlaylistVisible = !_isPlaylistVisible;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Center(
                    child: Text(
                      _cleanLyrics(widget.lyrics),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 2.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              _buildControlBar(),
            ],
          ),
          if (widget.playlistSongs != null)
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isPlaylistVisible ? 300 : 0,
                height: MediaQuery.of(context).size.height - 150,
                child: Card(
                  color: Colors.black87,
                  margin: EdgeInsets.zero,
                  child: _isPlaylistVisible
                      ? _buildPlaylistView()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistView() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getPlaylistSongsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final song = snapshot.data![index];
            final data = song.data() as Map<String, dynamic>;
            final isSelected = index == _currentSongIndex;

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.white24,
              leading: isSelected
                  ? const Icon(Icons.play_arrow, color: Colors.white)
                  : Text('${index + 1}',
                      style: const TextStyle(color: Colors.white70)),
              title: Text(
                data['title'],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                data['author'] ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => _navigateToSong(index, data),
            );
          },
        );
      },
    );
  }

  Stream<List<DocumentSnapshot>> _getPlaylistSongsStream() {
    if (widget.playlistSongs == null) return const Stream.empty();

    return Stream.fromFuture(
      Future.wait(
        widget.playlistSongs!.map(
          (id) => FirebaseFirestore.instance.collection('songs').doc(id).get(),
        ),
      ),
    );
  }

  void _navigateToSong(int index, Map<String, dynamic> songData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TeleprompterScreen(
          title: songData['title'],
          lyrics: songData['lyrics'],
          playlistSongs: widget.playlistSongs,
          currentIndex: index,
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetScroll,
          ),
          IconButton(
            icon: Icon(
              _isScrolling ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _toggleScroll,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () => _adjustSpeed(-5),
              ),
              Text(
                '${_scrollSpeed.toInt()}',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _adjustSpeed(5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cleanLyrics(String lyrics) {
    // Eliminar acordes entre paréntesis
    return lyrics.replaceAll(RegExp(r'\([^)]*\)'), '');
  }
}
