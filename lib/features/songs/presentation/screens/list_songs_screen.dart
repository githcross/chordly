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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

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
          if (isSelectionMode)
            AppBar(
              title: Text('${selectedSongs.length} seleccionadas'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _toggleSelectionMode(false),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => shareSongs(selectedSongs.toList()),
                ),
              ],
            ),
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
      floatingActionButton: !isSelectionMode
          ? FloatingActionButton(
              onPressed: () => _showOptions(context),
              child: const Icon(Icons.add),
            )
          : null,
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
      print(
          '[SHARE] Iniciando proceso de compartir ${songIds.length} canciones');
      if (songIds.isEmpty) return;

      // Obtener datos de las canciones
      print('[SHARE] Obteniendo datos de las canciones desde Firestore');
      final songs = await Future.wait(
        songIds.map((id) =>
            FirebaseFirestore.instance.collection('songs').doc(id).get()),
      );

      // Crear y compartir el PDF
      await _createPdfDocument(songs);

      if (mounted) {
        _toggleSelectionMode(false);
      }
      print('[SHARE] Proceso de compartir completado exitosamente');
    } catch (e) {
      print('[SHARE ERROR] Error durante el proceso: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  Future<void> _createPdfDocument(List<DocumentSnapshot> songs) async {
    try {
      print('[PDF] Iniciando creación de PDF con ${songs.length} canciones');

      // Crear documento PDF
      final pdf = pw.Document();

      // Cargar fuentes
      final mainFont =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldFont = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final mainTtf = pw.Font.ttf(mainFont);
      final boldTtf = pw.Font.ttf(boldFont);

      // Definir estilos
      final titleStyle = pw.TextStyle(
        font: boldTtf,
        fontSize: 24,
        color: PdfColors.blue,
      );

      final subtitleStyle = pw.TextStyle(
        font: mainTtf,
        fontSize: 14,
        color: PdfColors.grey,
      );

      final lyricStyle = pw.TextStyle(
        font: mainTtf,
        fontSize: 12,
        color: PdfColors.black,
      );

      final chordStyle = pw.TextStyle(
        font: boldTtf,
        fontSize: 10,
        color: PdfColors.red,
      );

      // Definir márgenes y tamaño de página
      final pageFormat = PdfPageFormat.a4;
      final margin = 50.0;
      final maxPageHeight = pageFormat.height - 2 * margin;

      // Función para agregar una página con el contenido de la canción
      void addSongPage(pw.Document pdf, String title, String author,
          String tempo, List<pw.Widget> lyricWidgets, bool isFirstPage) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (isFirstPage)
                    pw.Container(
                      padding: const pw.EdgeInsets.only(bottom: 20),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.blue,
                            width: 1,
                          ),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(title,
                              style: titleStyle,
                              textAlign: pw.TextAlign.center),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '$author - $tempo BPM',
                            style: subtitleStyle,
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  if (isFirstPage) pw.SizedBox(height: 30),
                  // Contenido
                  ...lyricWidgets,
                  // Pie de página
                  pw.Expanded(
                    child: pw.Container(
                      alignment: pw.Alignment.bottomCenter,
                      margin: const pw.EdgeInsets.only(top: 20),
                      child: pw.Text(
                        'Página ${context.pageNumber}',
                        style: pw.TextStyle(
                          font: mainTtf,
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      for (final song in songs) {
        print('[PDF] Procesando canción: ${song.id}');
        final data = song.data() as Map<String, dynamic>;
        final title = data['title'] as String? ?? 'Sin título';
        final author = data['author'] as String? ?? 'Autor desconocido';
        final tempo = data['tempo']?.toString() ?? '0';
        final lyrics = data['lyrics'] as String? ?? '';

        // Parsear los acordes y el texto
        final List<pw.Widget> lyricWidgets = [];
        final lines = lyrics.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) {
            lyricWidgets.add(pw.SizedBox(height: 16));
            continue;
          }

          final chordMatches = RegExp(r'\[(.*?)\]').allMatches(line);
          if (chordMatches.isEmpty) {
            lyricWidgets.add(pw.Text(line, style: lyricStyle));
            continue;
          }

          // Procesar línea con acordes
          final textSpans = <pw.TextSpan>[];
          int lastIndex = 0;
          for (final match in chordMatches) {
            // Texto antes del acorde
            if (match.start > lastIndex) {
              textSpans.add(pw.TextSpan(
                text: line.substring(lastIndex, match.start),
                style: lyricStyle,
              ));
            }

            // Acorde
            textSpans.add(pw.TextSpan(
              text: match.group(1),
              style: chordStyle,
            ));

            lastIndex = match.end;
          }

          // Texto restante
          if (lastIndex < line.length) {
            textSpans.add(pw.TextSpan(
              text: line.substring(lastIndex),
              style: lyricStyle,
            ));
          }

          lyricWidgets.add(pw.RichText(text: pw.TextSpan(children: textSpans)));
        }

        // Agregar la canción al PDF con paginación automática
        double currentHeight = 0;
        List<pw.Widget> currentPageWidgets = [];
        bool isFirstPage = true;

        for (final widget in lyricWidgets) {
          final widgetHeight = _estimateWidgetHeight(widget);

          if (currentHeight + widgetHeight > maxPageHeight) {
            addSongPage(
                pdf, title, author, tempo, currentPageWidgets, isFirstPage);
            isFirstPage = false;
            currentHeight = 0;
            currentPageWidgets = [];
          }

          currentPageWidgets.add(widget);
          currentHeight += widgetHeight;
        }

        // Agregar la última página si hay contenido restante
        if (currentPageWidgets.isNotEmpty) {
          addSongPage(
              pdf, title, author, tempo, currentPageWidgets, isFirstPage);
        }
      }

      // Guardar el PDF
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfFileName = songs.length == 1
          ? '${songs.first['title']}.pdf' // Nombre de la canción si es una sola
          : 'canciones_$timestamp.pdf'; // Nombre genérico si son varias
      final pdfPath = '${tempDir.path}/$pdfFileName';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      // Compartir el PDF
      await Share.shareFiles([pdfPath], text: 'Canciones compartidas');

      print('[PDF] Documento PDF creado exitosamente');
    } catch (e) {
      print('[PDF ERROR] Error durante la creación del PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  // Función para estimar la altura de un widget
  double _estimateWidgetHeight(pw.Widget widget) {
    if (widget is pw.Text) {
      // La propiedad style no existe en pw.Text, usamos un valor fijo
      return 12; // Altura predeterminada para texto
    } else if (widget is pw.SizedBox) {
      return widget.height ?? 0;
    } else if (widget is pw.RichText) {
      return widget.text.style?.fontSize ?? 12;
    }
    return 12; // Altura predeterminada
  }

  String _parseRichText(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'\[(.*?)\]'), (match) => '\n${match.group(1)}\n')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'_(.*?)_'), (match) => '${match.group(1)}');
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
                    print(
                        '[NAVIGATION] Intentando acceder a canción ID: ${song.id}');
                    print('[NAVIGATION] Grupo ID: ${widget.group.id}');
                    print(
                        '[NAVIGATION] Datos canción: ${song.data().toString()}');

                    if (song.id.isEmpty) {
                      print('[ERROR] ID de canción inválido');
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailsScreen(
                          songId: song.id,
                          groupId: widget.group.id,
                        ),
                      ),
                    ).catchError((e) {
                      print('[ERROR] Navigación fallida: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error al acceder a la canción: $e')),
                        );
                      }
                    });
                  },
                  onLongPress: () {
                    _toggleSelectionMode(true);
                    selectedSongs.add(song.id);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSelectionMode(bool value) {
    if (!mounted) return;
    setState(() {
      isSelectionMode = value;
      if (!value) selectedSongs.clear();
    });
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
      final result = await showFileSelector();

      if (result == null || result.isEmpty) return;

      // Leer el archivo
      final file = File(result.first.path!);
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

  Future<List<File>?> showFileSelector() async {
    final result = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return result != null ? [File(result.path)] : null;
  }
}
