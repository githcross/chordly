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

  void _showSymbolsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.music_note,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Símbolos Musicales'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSymbolExplanation(
                  context,
                  '(_Coro_)',
                  'Letra entre guion bajo',
                  'Indican la estructura de la letra. Ejemplo: (_Coro_) = Estructura del coro',
                ),
                const Divider(),
                _buildSymbolExplanation(
                  context,
                  '(Am)',
                  'Acordes entre paréntesis',
                  'Indican el acorde a tocar. Ejemplo: (Am) = La menor',
                ),
                const Divider(),
                _buildSymbolExplanation(
                  context,
                  '[Suave]',
                  'Comentarios entre corchetes',
                  'Instrucciones o notas sobre la interpretación. No aparecen en el teleprompter.',
                ),
                const Divider(),
                _buildSymbolExplanation(
                  context,
                  'C/G',
                  'Barra diagonal entre acordes',
                  'Indica un acorde con bajo específico. Ejemplo: C/G = Do con bajo en Sol',
                ),
                const Divider(),
                _buildSymbolExplanation(
                  context,
                  'Re-La',
                  'Guión entre acordes',
                  'Indica una transición o conexión entre acordes',
                ),
                const SizedBox(height: 16),
                Text(
                  'Consejo: Usa el botón de nota musical para insertar acordes fácilmente',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSymbolExplanation(
      BuildContext context, String symbol, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Letra de la canción',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => _showSymbolsInfo(context),
              tooltip: 'Símbolos musicales',
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: widget.onToggleFullScreen,
              tooltip: widget.isFullScreen
                  ? 'Salir de pantalla completa'
                  : 'Pantalla completa',
            ),
          ],
        ),
        const SizedBox(height: 8),
        widget.isFullScreen
            ? Expanded(
                child: _buildTextFormField(),
              )
            : SizedBox(
                height: 200, // Altura fija para modo normal
                child: _buildTextFormField(),
              ),
      ],
    );
  }

  Widget _buildTextFormField() {
    return TextFormField(
      controller: widget.controller,
      style: widget.style,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      validator: widget.validator,
      decoration: InputDecoration(
        errorText: widget.errorText,
        hintText: 'Escribe la letra con acordes...',
        helperText:
            'Formato: Selecciona nota para insertar o escribe la nota entre paréntesis',
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
