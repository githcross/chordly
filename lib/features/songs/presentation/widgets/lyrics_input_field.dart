import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/songs/services/chord_service.dart';
import 'package:chordly/features/songs/models/lyric_document.dart';

class LyricsInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final String? songId;
  final TextStyle? style;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final Function(String)? onChordSelected;
  final VoidCallback? onSectionInfoRequested;
  final bool isPreview;

  const LyricsInputField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.validator,
    this.songId,
    this.style,
    this.isFullScreen = false,
    this.onToggleFullScreen,
    this.onChordSelected,
    this.onSectionInfoRequested,
    this.isPreview = false,
  });

  @override
  State<LyricsInputField> createState() => _LyricsInputFieldState();
}

class _LyricsInputFieldState extends State<LyricsInputField> {
  late TextEditingController _controller;
  TextSelection? _previousSelection;
  final ChordService _chordService = ChordService();
  Map<String, List<String>> _noteCategories = {};
  bool _isLoadingChords = true;

  // Descripciones de las categorías
  final Map<String, String> _categoryDescriptions = {
    'Mayores': 'Acordes básicos incluyendo sostenidos (#) y bemoles (b)',
    'Menores': 'Acordes menores con sus variantes sostenidas y bemoles',
    'Séptima': 'Acordes mayores con séptima dominante y sus alteraciones',
    'Menor Séptima': 'Acordes menores con séptima y sus alteraciones',
    'Suspendidas': 'Acordes sus2 y sus4 con sus variantes alteradas',
    'Aumentadas y Disminuidas': 'Acordes aumentados (aum) y disminuidos (dim)',
  };

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_saveSelection);
    _loadChords();
  }

  Future<void> _loadChords() async {
    setState(() => _isLoadingChords = true);
    try {
      final categories = await _chordService.getChordCategories();
      setState(() {
        _noteCategories = categories;
        _isLoadingChords = false;
      });
    } catch (e) {
      setState(() => _isLoadingChords = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar los acordes'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_saveSelection);
    super.dispose();
  }

  void _saveSelection() {
    _previousSelection = _controller.selection;
  }

  void _restoreSelection() {
    if (_previousSelection != null && _controller.text.isNotEmpty) {
      final end = _previousSelection!.end.clamp(0, _controller.text.length);
      final start = _previousSelection!.start.clamp(0, end);
      _controller.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
    }
  }

  void _insertChord(String note) async {
    final text = _controller.text;
    final selection = _controller.selection;

    // Obtener la línea actual y su índice
    final lines = text.split('\n');
    int currentLineIndex = 0;
    int currentPosition = 0;

    // Encontrar la línea actual basada en la posición del cursor
    for (int i = 0; i < lines.length; i++) {
      if (currentPosition + lines[i].length + 1 > selection.start) {
        currentLineIndex = i;
        break;
      }
      currentPosition += lines[i].length + 1;
    }

    // Obtener la línea actual y su indentación
    final currentLine = lines[currentLineIndex];
    final leadingSpaces = RegExp(r'^\s*').firstMatch(currentLine)?[0] ?? '';

    // Calcular la posición relativa dentro de la línea
    final positionInLine = selection.start - currentPosition;

    // Si estamos al inicio de la línea o antes de cualquier texto, preservar la indentación
    if (positionInLine <= leadingSpaces.length) {
      // Insertar después de los espacios iniciales
      final beforeInsertion =
          text.substring(0, currentPosition + leadingSpaces.length);
      final afterInsertion =
          text.substring(currentPosition + leadingSpaces.length);
      final newText = beforeInsertion + '($note)' + afterInsertion;

      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: currentPosition + leadingSpaces.length + note.length + 2,
        ),
      );
    } else {
      // Inserción normal en medio o final de la línea
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '($note)',
      );

      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + note.length + 2,
        ),
      );
    }

    // Actualizar en Firestore si hay songId
    if (widget.songId != null) {
      try {
        final songDoc =
            FirebaseFirestore.instance.collection('songs').doc(widget.songId);
        final lyricDoc = LyricDocument.fromInlineText(_controller.text);
        await songDoc.update({
          'lyrics': _controller.text,
          'topFormat': lyricDoc.toTopFormat(),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar la letra: $e')),
          );
        }
      }
    }

    if (widget.onChanged != null) {
      widget.onChanged!(_controller.text);
    }
  }

  void _showChordDialog(BuildContext context) {
    if (widget.onChordSelected != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          if (_isLoadingChords) {
            return const AlertDialog(
              title: Text('Cargando Acordes'),
              content: Center(child: CircularProgressIndicator()),
            );
          }

          return AlertDialog(
            title: const Text('Seleccionar Acorde'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_noteCategories.isEmpty)
                    const Text('No hay acordes disponibles')
                  else
                    ..._noteCategories.entries.map((category) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(
                                category.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              subtitle: Text(
                                _categoryDescriptions[category.key] ??
                                    'Otros acordes',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: category.value.map((note) {
                                  return ActionChip(
                                    label: Text(note),
                                    labelStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _insertChord(note);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              if (_noteCategories.isNotEmpty)
                TextButton(
                  onPressed: _loadChords,
                  child: const Text('Recargar'),
                ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: null,
      minLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: widget.style,
      strutStyle: StrutStyle(
        fontSize: widget.style?.fontSize,
        height: widget.style?.height ?? 1.5,
        leading: 0.5,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        hintText: 'Escribe la letra y acordes aquí...',
        suffixIcon: widget.isFullScreen && widget.onChordSelected != null
            ? IconButton(
                icon: const Icon(Icons.music_note),
                onPressed: () => _showChordDialog(context),
              )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }

  void _showBasicSymbolsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Símbolos Esenciales'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem('( )', 'Acordes', 'Ej: (C) = Do Mayor'),
              _buildHelpItem(
                  '/', 'Bajo en', 'Ej: Am/C = La menor con bajo en Do'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String symbol, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symbol,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
