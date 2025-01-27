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

class ListSongsScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const ListSongsScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<ListSongsScreen> createState() => _ListSongsScreenState();
}

class _ListSongsScreenState extends ConsumerState<ListSongsScreen> {
  bool _ascendingOrder = true;
  Set<String> _selectedTags = {};
  String? _lastDeletedSongId;
  String? _lastDeletedSongTitle;
  OverlayEntry? _overlayEntry;
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;
  Set<String> _selectedSongs = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedSongs.length} seleccionados'
              : 'Canciones',
          style: AppTextStyles.appBarTitle(context),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedSongs.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _selectedSongs.isNotEmpty
                  ? () => _shareSongs(_selectedSongs.toList())
                  : null,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                  _ascendingOrder ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _ascendingOrder
                  ? 'Ordenar descendente'
                  : 'Ordenar ascendente',
              onPressed: () {
                setState(() {
                  _ascendingOrder = !_ascendingOrder;
                });
              },
            ),
            IconButton(
              icon: Badge(
                isLabelVisible: _selectedTags.isNotEmpty,
                label: Text(_selectedTags.length.toString()),
                child: const Icon(Icons.tag),
              ),
              tooltip: 'Filtrar por tags',
              onPressed: _showTagFilter,
            ),
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
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getSongsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data?.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Filtrar por término de búsqueda si existe
                  if (_searchController.text.isNotEmpty) {
                    final searchTerm = _searchController.text.toLowerCase();
                    final title = (data['title'] as String).toLowerCase();
                    return title.contains(searchTerm);
                  }
                  return true;
                }).toList();

                if (songs == null || songs.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron canciones'),
                  );
                }

                return _buildSongList(songs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<QueryDocumentSnapshot>> _getSongsStream() {
    final user = ref.read(authProvider).value;
    if (user == null) return const Stream.empty();

    // Query para canciones publicadas
    final publishedQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'publicado')
        .snapshots();

    // Query para borradores del usuario actual
    final draftsQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'borrador')
        .where('createdBy', isEqualTo: user.uid)
        .snapshots();

    // Combinar los streams y ordenar
    return Rx.combineLatest2(
      publishedQuery,
      draftsQuery,
      (QuerySnapshot published, QuerySnapshot drafts) {
        final allDocs = [...published.docs, ...drafts.docs];
        // Filtrar por tags si hay seleccionados
        final filteredDocs = _selectedTags.isEmpty
            ? allDocs
            : allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final tags = List<String>.from(data['tags'] ?? []);
                return _selectedTags.every((tag) => tags.contains(tag));
              }).toList();

        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTitle = aData['title'] as String;
          final bTitle = bData['title'] as String;
          return _ascendingOrder
              ? aTitle.compareTo(bTitle)
              : bTitle.compareTo(aTitle);
        });
        return filteredDocs;
      },
    );
  }

  Future<void> _shareSongs(List<String> songIds) async {
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
        _isSelectionMode = false;
        _selectedSongs.clear();
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

    for (var song in songs) {
      final data = song.data() as Map<String, dynamic>;
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      final Rect bounds = Rect.fromLTWH(40, 40, page.getClientSize().width - 80,
          page.getClientSize().height - 80);

      // Agregar título
      graphics.drawString(
        data['title'],
        titleFont,
        bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 30),
      );

      // Agregar autor
      graphics.drawString(
        'Autor: ${data['author']}',
        subtitleFont,
        bounds: Rect.fromLTWH(bounds.left, bounds.top + 40, bounds.width, 20),
      );

      // Agregar letra
      graphics.drawString(
        data['lyrics'],
        contentFont,
        bounds: Rect.fromLTWH(
            bounds.left, bounds.top + 80, bounds.width, bounds.height - 80),
        format: PdfStringFormat(lineSpacing: 5),
      );
    }
  }

  Future<void> _showTagFilter() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    // Obtener todas las canciones publicadas y borradores del usuario
    final publishedSnapshot = await FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'publicado')
        .get();

    final draftsSnapshot = await FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'borrador')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    // Combinar los documentos
    final allDocs = [...publishedSnapshot.docs, ...draftsSnapshot.docs];

    // Extraer todos los tags únicos
    final allTags = allDocs.fold<Set<String>>(
      {},
      (tags, doc) {
        final songTags = List<String>.from(doc.data()['tags'] ?? []);
        return tags..addAll(songTags);
      },
    ).toList();

    if (!mounted) return;

    // Mostrar diálogo de selección de tags
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por tags'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTags.clear();
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

  void _showDeleteBanner(String songTitle) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
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
                          .doc(_lastDeletedSongId)
                          .update({'isActive': true});
                      _overlayEntry?.remove();
                      _overlayEntry = null;
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

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
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
                      _showBackupDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Importar canciones'),
                    subtitle: const Text('Restaurar desde copia de seguridad'),
                    onTap: () {
                      Navigator.pop(context);
                      _showRestoreDialog();
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

  Future<void> _showBackupDialog() async {
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

  Future<void> _showRestoreDialog() async {
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

  void _addSong(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSongScreen(groupId: widget.group.id),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
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
            final songData = songs[index].data() as Map<String, dynamic>;
            final songId = songs[index].id;

            return Dismissible(
              key: Key(songId),
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
                  ? (direction) => _confirmDelete(context, songData, songId)
                  : null,
              onDismissed: canDelete
                  ? (direction) async {
                      _lastDeletedSongId = songId;
                      _lastDeletedSongTitle = songData['title'];

                      await FirebaseFirestore.instance
                          .collection('songs')
                          .doc(songId)
                          .update({'isActive': false});

                      if (mounted) {
                        _showDeleteBanner(_lastDeletedSongTitle!);
                      }
                    }
                  : null,
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    songData['title'],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        songData['author'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      if (songData['baseKey'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              songData['baseKey'],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    try {
      final songs = await FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: widget.group.id)
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> backupData = [];

      for (var doc in songs.docs) {
        final songData = doc.data();
        // Preservar todos los campos relevantes para el formato
        final cleanData = {
          'title': songData['title'],
          'author': songData['author'],
          'lyrics': songData['lyrics'],
          'lyricsTranspose': songData['lyricsTranspose'],
          'baseKey': songData['baseKey'],
          'tempo': songData['tempo'],
          'tags': songData['tags'],
          'notes': songData['notes'],
          // Campos adicionales para preservar formato
          'format': {
            'spacing': songData['format']?['spacing'] ?? 1.5,
            'alignment': songData['format']?['alignment'] ?? 'left',
            'indentation': songData['format']?['indentation'] ?? 0.0,
            'chordPosition': songData['format']?['chordPosition'] ?? 'above',
            'fontSize': songData['format']?['fontSize'] ?? 16.0,
            'chordFontSize': songData['format']?['chordFontSize'] ?? 14.0,
          },
          // Metadatos originales
          'originalCreatedAt':
              songData['createdAt']?.toDate().toIso8601String(),
          'originalUpdatedAt':
              songData['updatedAt']?.toDate().toIso8601String(),
          'status': songData['status'] ?? 'borrador',
          'version': songData['version'] ?? 1,
          // Campos de visualización
          'displayOptions': {
            'showChords': songData['displayOptions']?['showChords'] ?? true,
            'showNotes': songData['displayOptions']?['showNotes'] ?? true,
            'showTempo': songData['displayOptions']?['showTempo'] ?? true,
          },
        };
        backupData.add(cleanData);
      }

      // Crear el objeto de backup con metadatos
      final backup = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'groupName': widget.group.name,
        'groupId': widget.group.id,
        'totalSongs': songs.docs.length,
        'songs': backupData,
      };

      // Convertir a JSON con formato legible (usando dart:convert)
      final jsonString = JsonEncoder.withIndent('  ').convert(backup);

      // Guardar el archivo
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'chordly_backup_${timestamp}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Compartir el archivo
      await Share.shareFiles(
        [file.path],
        text: 'Backup de canciones de ${widget.group.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup creado exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear backup: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      // Abrir selector de archivos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validar versión y formato
      if (backup['version'] != '1.0') {
        throw 'Versión de backup no compatible';
      }

      // Mostrar diálogo de confirmación
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importar canciones'),
          content: Text(
              '¿Deseas importar ${backup['totalSongs']} canciones del grupo "${backup['groupName']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Importar canciones preservando el formato
      final batch = FirebaseFirestore.instance.batch();
      final songs = backup['songs'] as List;

      for (var songData in songs) {
        final docRef = FirebaseFirestore.instance.collection('songs').doc();
        final now = DateTime.now();

        // Preservar el formato original
        final importedData = {
          'title': songData['title'],
          'author': songData['author'],
          'lyrics': songData['lyrics'],
          'lyricsTranspose': songData['lyricsTranspose'],
          'baseKey': songData['baseKey'],
          'tempo': songData['tempo'],
          'tags': songData['tags'] ?? [],
          'notes': songData['notes'],
          // Preservar formato
          'format': songData['format'] ??
              {
                'spacing': 1.5,
                'alignment': 'left',
                'indentation': 0.0,
                'chordPosition': 'above',
                'fontSize': 16.0,
                'chordFontSize': 14.0,
              },
          // Preservar opciones de visualización
          'displayOptions': songData['displayOptions'] ??
              {
                'showChords': true,
                'showNotes': true,
                'showTempo': true,
              },
          // Datos requeridos
          'groupId': widget.group.id,
          'isActive': true,
          'status': songData['status'] ?? 'borrador',
          'version': songData['version'] ?? 1,
          // Fechas y usuarios
          'createdAt': now,
          'updatedAt': now,
          'originalCreatedAt': songData['originalCreatedAt'],
          'originalUpdatedAt': songData['originalUpdatedAt'],
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'lastUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
        };

        batch.set(docRef, importedData);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canciones importadas exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar canciones: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _isSongInPlaylist(String songId) async {
    try {
      // Buscar en todas las playlists del grupo
      final playlistsQuery = await FirebaseFirestore.instance
          .collection('playlists')
          .where('groupId', isEqualTo: widget.group.id)
          .where('isActive', isEqualTo: true)
          .get();

      for (var playlist in playlistsQuery.docs) {
        final songs = List<String>.from(playlist.data()['songs'] ?? []);
        if (songs.contains(songId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error al verificar playlists: $e');
      return false;
    }
  }

  Future<bool> _confirmDelete(BuildContext context,
      Map<String, dynamic> songData, String songId) async {
    // Verificar si la canción está en alguna playlist
    final inPlaylist = await _isSongInPlaylist(songId);

    if (inPlaylist) {
      if (!mounted) return false;

      // Mostrar mensaje de error si la canción está en uso
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'La canción "${songData['title']}" está en uso en una o más playlists.'),
              const SizedBox(height: 8),
              const Text(
                'Para eliminarla, primero debes quitarla de todas las playlists.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return false;
    }

    // Si no está en uso, mostrar confirmación normal
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
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
}
