import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/delegates/song_search_delegate.dart';
import 'package:chordly/features/songs/presentation/screens/deleted_songs_screen.dart';
import 'package:chordly/features/songs/providers/songs_provider.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/songs/presentation/screens/add_song_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';

class ListSongsScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const ListSongsScreen({
    super.key,
    required this.group,
  });

  @override
  ListSongsScreenState createState() => ListSongsScreenState();
}

class ListSongsScreenState extends ConsumerState<ListSongsScreen> {
  bool ascendingOrder = true;
  Set<String> selectedTags = {};
  String? lastDeletedSongId;
  String? lastDeletedSongTitle;
  OverlayEntry? overlayEntry;
  final searchController = TextEditingController();
  bool isSelectionMode = false;
  Set<String> selectedSongs = {};
  List<QueryDocumentSnapshot> _currentFilteredSongs = [];
  int currentFilteredCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getSongsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                currentFilteredCount =
                    selectedTags.isEmpty ? 0 : snapshot.data!.length;
                return _buildSongList(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<QueryDocumentSnapshot>> _getSongsStream() {
    final user = ref.read(authProvider).value;
    if (user == null) return Stream.value([]);

    Query query = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true);

    if (selectedTags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: selectedTags);
    }

    query = ascendingOrder
        ? query.orderBy('title', descending: false)
        : query.orderBy('title', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final userId = data['userId'] as String?;

        return status == 'publicado' ||
            (status == 'borrador' && userId == user.uid);
      }).toList();
    });
  }

  Future<void> shareSongs(List<String> songIds) async {
    try {
      if (songIds.isEmpty) return;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfPath = '${tempDir.path}/songs_$timestamp.pdf';

      // Obtener datos de las canciones
      final songs = await Future.wait(
        songIds.map((id) =>
            FirebaseFirestore.instance.collection('songs').doc(id).get()),
      );

      // Crear y guardar el PDF
      final document = PdfDocument();
      _createPdfDocument(document, songs);
      final List<int> bytes = await document.save();
      await File(pdfPath).writeAsBytes(bytes);
      document.dispose();

      // Compartir el PDF
      await Share.shareFiles([pdfPath], text: 'Canciones compartidas');

      setState(() {
        isSelectionMode = false;
        selectedSongs.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  void _createPdfDocument(PdfDocument document, List<DocumentSnapshot> songs) {
    // Configurar estilo del documento
    final PdfStandardFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final PdfStandardFont subtitleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14);
    final PdfStandardFont contentFont =
        PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfStandardFont chordFont =
        PdfStandardFont(PdfFontFamily.helvetica, 10);

    // Colores para diferentes elementos
    final PdfColor chordColor = PdfColor(0, 122, 255); // Azul para acordes
    final PdfColor sectionColor =
        PdfColor(255, 196, 0); // Amarillo para secciones
    final PdfColor noteColor = PdfColor(0, 122, 255); // Azul para notas [...]

    // Función para limpiar caracteres no soportados
    String cleanText(String text) {
      return text
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('ñ', 'n')
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ú', 'U')
          .replaceAll('Ñ', 'N')
          .replaceAll(RegExp(r'[^\x20-\x7E]'),
              ''); // Mantener solo caracteres ASCII imprimibles
    }

    for (var song in songs) {
      final data = song.data() as Map<String, dynamic>;
      final PdfPage page = document.pages.add();
      var graphics = page.graphics;
      final Rect bounds = Rect.fromLTWH(40, 40, page.getClientSize().width - 80,
          page.getClientSize().height - 80);

      // Agregar título
      graphics.drawString(
        cleanText(data['title']),
        titleFont,
        bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 30),
      );

      // Agregar autor
      if (data['author'] != null && data['author'].toString().isNotEmpty) {
        graphics.drawString(
          'Autor: ${cleanText(data['author'])}',
          subtitleFont,
          bounds: Rect.fromLTWH(bounds.left, bounds.top + 40, bounds.width, 20),
        );
      }

      // Agregar tags si existen
      if (data['tags'] != null && (data['tags'] as List).isNotEmpty) {
        final tags = (data['tags'] as List)
            .map((tag) => cleanText(tag.toString()))
            .join(', ');
        graphics.drawString(
          'Tags: $tags',
          subtitleFont,
          bounds: Rect.fromLTWH(bounds.left, bounds.top + 60, bounds.width, 20),
        );
      }

      // Procesar y agregar letra con formato
      if (data['lyrics'] != null && data['lyrics'].toString().isNotEmpty) {
        final lyrics = data['lyrics'].toString();
        final lines = lyrics.split('\n');
        double yPosition = bounds.top + 100;
        final lineHeight = contentFont.height * 1.5;

        for (var line in lines) {
          // Si no hay suficiente espacio en la página actual, crear una nueva
          if (yPosition + lineHeight > bounds.bottom) {
            final newPage = document.pages.add();
            graphics = newPage.graphics;
            yPosition = bounds.top;
          }

          // Procesar línea para diferentes formatos
          if (line.contains('(') && line.contains(')')) {
            // Línea con acordes
            final parts = line.split(RegExp(r'(\([^)]+\))'));
            double xPosition = bounds.left;

            for (var i = 0; i < parts.length; i++) {
              if (i % 2 == 0) {
                // Texto normal
                graphics.drawString(
                  cleanText(parts[i]),
                  contentFont,
                  brush: PdfSolidBrush(PdfColor(0, 0, 0)),
                  bounds: Rect.fromLTWH(
                      xPosition, yPosition, bounds.width, lineHeight),
                );
                xPosition +=
                    contentFont.measureString(cleanText(parts[i])).width;
              } else {
                // Acordes
                graphics.drawString(
                  cleanText(parts[i]),
                  chordFont,
                  brush: PdfSolidBrush(chordColor),
                  bounds: Rect.fromLTWH(
                      xPosition, yPosition, bounds.width, lineHeight),
                );
                xPosition += chordFont.measureString(cleanText(parts[i])).width;
              }
            }
          } else if (line.startsWith('_') && line.endsWith('_')) {
            // Secciones (entre guiones bajos)
            graphics.drawString(
              cleanText(line.substring(1, line.length - 1)),
              contentFont,
              brush: PdfSolidBrush(sectionColor),
              bounds: Rect.fromLTWH(
                  bounds.left, yPosition, bounds.width, lineHeight),
            );
          } else if (line.contains('[') && line.contains(']')) {
            // Notas (entre corchetes)
            final parts = line.split(RegExp(r'(\[[^\]]+\])'));
            double xPosition = bounds.left;

            for (var i = 0; i < parts.length; i++) {
              if (i % 2 == 0) {
                // Texto normal
                graphics.drawString(
                  cleanText(parts[i]),
                  contentFont,
                  brush: PdfSolidBrush(PdfColor(0, 0, 0)),
                  bounds: Rect.fromLTWH(
                      xPosition, yPosition, bounds.width, lineHeight),
                );
                xPosition +=
                    contentFont.measureString(cleanText(parts[i])).width;
              } else {
                // Notas
                graphics.drawString(
                  cleanText(parts[i]),
                  contentFont,
                  brush: PdfSolidBrush(noteColor),
                  bounds: Rect.fromLTWH(
                      xPosition, yPosition, bounds.width, lineHeight),
                );
                xPosition +=
                    contentFont.measureString(cleanText(parts[i])).width;
              }
            }
          } else {
            // Texto normal
            graphics.drawString(
              cleanText(line),
              contentFont,
              bounds: Rect.fromLTWH(
                  bounds.left, yPosition, bounds.width, lineHeight),
            );
          }

          yPosition += lineHeight;
        }
      }
    }
  }

  Future<void> showBackupDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear copia de seguridad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se exportarán:'),
            const SizedBox(height: 8),
            const Text('• Todas las canciones del grupo'),
            const Text('• Configuración y formato de cada canción'),
            const Text('• Acordes y notas'),
            const SizedBox(height: 16),
            Text(
              'El archivo se guardará con el nombre: chordly_backup_${widget.group.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.json',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exportar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _exportBackup();
    }
  }

  Future<void> showRestoreDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar desde backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Importante',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Al importar canciones:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('• Se agregarán como nuevas canciones'),
            const Text('• No se sobrescribirán las existentes'),
            const Text('• Se mantendrá el formato original'),
            const Text('• Se importarán como borradores'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seleccionar archivo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _importBackup();
    }
  }

  Future<void> showTagFilter() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final tagsSnapshot = await FirebaseFirestore.instance
        .collection('tags')
        .doc('default')
        .get();

    if (!tagsSnapshot.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron tags')),
        );
      }
      return;
    }

    final allTags = List<String>.from(tagsSnapshot.data()?['tags'] ?? []);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filtrar por tags'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    return FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (selected) {
                        // Actualizar estado padre y UI del diálogo
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                        setDialogState(() {}); // Forzar rebuild del diálogo
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedTags.clear();
                      currentFilteredCount = 0;
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
            );
          },
        );
      },
    );
  }

  void _showDeleteBanner(String songTitle) {
    overlayEntry?.remove();
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se eliminó "$songTitle"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('songs')
                          .doc(lastDeletedSongId)
                          .update({'isActive': true});
                      overlayEntry?.remove();
                      overlayEntry = null;
                    },
                    child: const Text('DESHACER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StreamBuilder<GroupRole>(
        stream: _getUserRole(),
        builder: (context, snapshot) {
          final userRole = snapshot.data ?? GroupRole.member;
          final isAdmin = userRole == GroupRole.admin;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Agregar canción'),
                  onTap: () {
                    Navigator.pop(context);
                    _addSong(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Ver canciones eliminadas'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeletedSongsScreen(
                          group: widget.group,
                        ),
                      ),
                    );
                  },
                ),
                if (isAdmin) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text('Exportar canciones'),
                    subtitle: const Text('Crear copia de seguridad del grupo'),
                    onTap: () {
                      Navigator.pop(context);
                      showBackupDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Importar canciones'),
                    subtitle: const Text('Restaurar desde copia de seguridad'),
                    onTap: () {
                      Navigator.pop(context);
                      showRestoreDialog();
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _addSong(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSongScreen(
          groupId: widget.group.id,
          isEditing: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    overlayEntry?.remove();
    super.dispose();
  }

  // Agregar stream para el rol del usuario
  Stream<GroupRole> _getUserRole() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(GroupRole.member);

    return FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.group.id)
        .collection('memberships')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return GroupRole.member;

      // Convertir string a GroupRole de forma segura
      final roleStr = snapshot.data()?['role'] as String? ?? 'member';
      switch (roleStr.toLowerCase()) {
        case 'admin':
          return GroupRole.admin;
        case 'editor':
          return GroupRole.editor;
        default:
          return GroupRole.member;
      }
    });
  }

  Widget _buildSongList(List<QueryDocumentSnapshot> songs) {
    return StreamBuilder<GroupRole>(
      stream: _getUserRole(),
      builder: (context, roleSnapshot) {
        final userRole = roleSnapshot.data ?? GroupRole.member;
        final canDelete =
            userRole == GroupRole.admin || userRole == GroupRole.editor;

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final data = song.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'Sin título';
            final author = data['author'] as String? ?? 'Autor desconocido';
            final tempo = data['tempo']?.toString() ??
                '0'; // Asegurar que el tempo sea un String
            final isDraft = data['status'] == 'borrador';

            return Dismissible(
              key: Key(song.id),
              direction: canDelete
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: canDelete
                  ? (direction) => _confirmDelete(context, data, song.id)
                  : null,
              onDismissed: canDelete
                  ? (direction) async {
                      lastDeletedSongId = song.id;
                      lastDeletedSongTitle = title;

                      await FirebaseFirestore.instance
                          .collection('songs')
                          .doc(song.id)
                          .update({'isActive': false});

                      if (mounted) {
                        _showDeleteBanner(lastDeletedSongTitle!);
                      }
                    }
                  : null,
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: isSelectionMode
                      ? Checkbox(
                          value: selectedSongs.contains(song.id),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedSongs.add(song.id);
                              } else {
                                selectedSongs.remove(song.id);
                              }
                            });
                          },
                        )
                      : null,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      if (isDraft)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Borrador',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '$author - $tempo BPM',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8),
                        ),
                  ),
                  onTap: () {
                    if (isSelectionMode) {
                      setState(() {
                        if (selectedSongs.contains(song.id)) {
                          selectedSongs.remove(song.id);
                        } else {
                          selectedSongs.add(song.id);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SongDetailsScreen(
                            songId: song.id,
                            groupId: widget.group.id,
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      if (!isSelectionMode) {
                        isSelectionMode = true;
                        selectedSongs.add(song.id);
                      }
                    });
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    try {
      final user = ref.read(authProvider).value;
      if (user == null) return;

      final songsSnapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: widget.group.id)
          .where('isActive', isEqualTo: true)
          .get();

      final songs = songsSnapshot.docs.map((doc) {
        final data = doc.data();
        return data.map((key, value) {
          if (value is Timestamp) {
            return MapEntry(key, value.toDate().toIso8601String());
          }
          if (value is DocumentReference) {
            return MapEntry(key, value.path);
          }
          if (value is GeoPoint) {
            return MapEntry(
                key, {'lat': value.latitude, 'lng': value.longitude});
          }
          return MapEntry(key, value);
        });
      }).toList();

      final backup = {
        'groupId': widget.group.id,
        'groupName': widget.group.name,
        'exportDate': DateTime.now().toIso8601String(),
        'songs': songs,
        'metadata': {
          'appVersion': '2.0.0',
          'deviceOS': Platform.operatingSystem,
          'exportedBy': user.email ?? 'Usuario no identificado',
        },
      };

      final jsonString = jsonEncode(backup);
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'chordly_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareFiles(
        [file.path],
        text: 'Copia de seguridad de canciones - ${widget.group.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      // Leer el archivo
      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      // Verificar que es un backup válido
      if (!backup.containsKey('songs')) {
        throw Exception('Archivo de backup inválido');
      }

      // Obtener el usuario actual
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Usuario no autenticado');

      // Importar cada canción
      final batch = FirebaseFirestore.instance.batch();
      final songs = backup['songs'] as List;

      for (final song in songs) {
        final songData = Map<String, dynamic>.from(song as Map);
        songData['groupId'] = widget.group.id;
        songData['createdBy'] = user.uid;
        songData['createdAt'] = FieldValue.serverTimestamp();
        songData['updatedAt'] = FieldValue.serverTimestamp();
        songData['status'] = songData['status'] ?? 'borrador';
        songData['isActive'] = songData['isActive'] ?? true;
        songData['lyrics'] = songData['lyrics'] ?? '';
        songData['lyricsTranspose'] =
            songData['lyricsTranspose'] ?? songData['lyrics'];
        songData['topFormat'] = songData['topFormat'] ?? '';
        songData['baseKey'] = songData['baseKey'] ?? '';
        songData['tempo'] = songData['tempo'] ?? 0;
        songData['duration'] = songData['duration'] ?? '';
        songData['videoReference'] = songData['videoReference'] ?? {};
        songData['tags'] = songData['tags'] ?? [];
        songData['collaborators'] = songData['collaborators'] ?? [];

        // Remover el ID del documento original
        songData.remove('id');

        final newSongRef = FirebaseFirestore.instance.collection('songs').doc();
        batch.set(newSongRef, songData);
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${songs.length} canciones importadas con su estado original'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> songData,
    String songId,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar canción'),
            content: Text(
                '¿Estás seguro de que quieres eliminar "${songData['title']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Query<Object?> _songsQuery() {
    Query query = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true);

    if (selectedTags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: selectedTags);
    }

    query = ascendingOrder
        ? query.orderBy('title', descending: false)
        : query.orderBy('title', descending: true);

    return query;
  }
}
