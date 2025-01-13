import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'song_detail_screen.dart';
import '../utils/constants.dart';
import 'archived_songs_screen.dart';
import 'add_song_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SongsScreen extends StatefulWidget {
  final String groupId;

  const SongsScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  _SongsScreenState createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  String _sortOrder = 'asc';

  void _shareSongs(List<Map<String, dynamic>> songs) async {
    // Ordenar canciones alfabéticamente
    songs.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Lista de Canciones',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              ...songs.map((song) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Título: ${song['title'] ?? 'Sin título'}',
                        style: pw.TextStyle(fontSize: 18)),
                    pw.Text('Autor: ${song['author'] ?? 'Autor desconocido'}',
                        style: pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 10),
                  ],
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    final output = await pdf.save();
    await Printing.sharePdf(bytes: output, filename: 'lista_canciones.pdf');
  }

  void _showCustomSnackBar({
    required BuildContext context,
    required Widget content,
    Duration duration = const Duration(seconds: 3),
    required Function onUndo,
  }) {
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20,
        left: 16,
        right: 16,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.horizontal,
          onDismissed: (_) {
            overlayEntry?.remove();
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      child: content,
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      onUndo();
                      overlayEntry?.remove();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(40, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Deshacer',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry?.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Canciones del Grupo"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, size: kIconSize, color: kIconColor),
            tooltip: "Ver canciones archivadas",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArchivedSongsScreen(),
                ),
              );
              setState(() {});
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('songs')
                .where('isArchived', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final songs = snapshot.data?.docs ?? [];
              return IconButton(
                icon: Icon(Icons.share, size: kIconSize, color: kIconColor),
                onPressed: () => _shareSongs(songs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                _sortOrder = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return ['asc', 'desc'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice == 'asc' ? 'Ordenar A-Z' : 'Ordenar Z-A'),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.search, size: kIconSize, color: kIconColor),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(groupId: widget.groupId),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          var songs = List<Map<String, dynamic>>.from(groupData['songs'] ?? []);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('songs')
                .where('isArchived', isEqualTo: false)
                .snapshots(),
            builder: (context, songsSnapshot) {
              if (!songsSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              var filteredSongs = songs.where((groupSong) {
                return songsSnapshot.data!.docs
                    .any((doc) => doc.id == groupSong['songId']);
              }).toList();

              if (_sortOrder == 'asc') {
                filteredSongs.sort(
                    (a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
              } else {
                filteredSongs.sort(
                    (a, b) => (b['title'] ?? '').compareTo(a['title'] ?? ''));
              }

              if (filteredSongs.isEmpty) {
                return Center(
                  child: Text(
                    'No hay canciones en este grupo',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = filteredSongs[index];
                  return Dismissible(
                    key: Key(song['songId']),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Eliminar del grupo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) async {
                      final songRef = FirebaseFirestore.instance
                          .collection('songs')
                          .doc(song['songId']);

                      try {
                        await songRef.update({'isArchived': true});

                        _showCustomSnackBar(
                          context: context,
                          content: Text(
                            'Canción archivada',
                            style: TextStyle(color: Colors.white),
                          ),
                          onUndo: () async {
                            await songRef.update({'isArchived': false});
                          },
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Error al archivar la canción: $e'),
                              ],
                            ),
                            margin: EdgeInsets.only(
                              bottom: 60,
                              left: 16,
                              right: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: ListTile(
                      leading: Icon(Icons.music_note),
                      title: Text(song['title'] ?? 'Sin título'),
                      subtitle: Text(
                        '${song['author'] ?? 'Autor desconocido'} • ${song['baseKey'] ?? 'Sin clave'}',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongDetailScreen(
                              songId: song['songId'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSongScreen(groupId: widget.groupId),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class SongSearchDelegate extends SearchDelegate<String> {
  final String groupId;

  SongSearchDelegate({required this.groupId});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final groupData = snapshot.data!.data() as Map<String, dynamic>;
        final songs = List<Map<String, dynamic>>.from(groupData['songs'] ?? []);

        final results = songs.where((song) {
          final title = song['title']?.toLowerCase() ?? '';
          final author = song['author']?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || author.contains(searchLower);
        }).toList();

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final song = results[index];
            return ListTile(
              title: Text(song['title'] ?? 'Sin título'),
              subtitle: Text(song['author'] ?? 'Autor desconocido'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongDetailScreen(
                      songId: song['songId'],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(child: Text('Busca por título o autor'));
  }
}
