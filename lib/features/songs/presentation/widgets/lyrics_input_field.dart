import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/songs/services/chord_service.dart';

class LyricsInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final String? songId;
  final TextStyle? style;

  const LyricsInputField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.validator,
    this.songId,
    this.style,
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
    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '($note)$selectedText',
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + newText.length - text.length,
      ),
    );

    try {
      if (widget.songId != null) {
        final songDoc =
            FirebaseFirestore.instance.collection('songs').doc(widget.songId);
        await songDoc.update({'lyrics': newText});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la letra: $e')),
      );
    }
  }

  void _showChordDialog(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      style: widget.style,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      validator: widget.validator,
      decoration: InputDecoration(
        errorText: widget.errorText,
        hintText: 'Escribe la letra con acordes...',
        helperText: 'Formato: {[Am]}palabra{/}',
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.music_note),
          tooltip: 'Insertar acorde',
          onPressed: () => _showChordDialog(context),
        ),
      ),
      onChanged: (value) {
        widget.onChanged?.call(value);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreSelection();
        });
      },
    );
  }
}
