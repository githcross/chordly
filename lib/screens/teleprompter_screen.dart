import 'package:flutter/material.dart';

class TeleprompterScreen extends StatefulWidget {
  final String lyrics;

  TeleprompterScreen({required this.lyrics});

  @override
  _TeleprompterScreenState createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends State<TeleprompterScreen> {
  late ScrollController _scrollController;
  double _scrollSpeed = 30.0; // Velocidad inicial
  bool _showChords = false; // Por defecto, los acordes están ocultos
  bool _isPlaying = true; // Controlar estado Play/Pausa

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startScrolling();
  }

  // Función para iniciar o reiniciar el desplazamiento
  void _startScrolling() {
    if (_scrollController.hasClients && _isPlaying) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(
            seconds: (_scrollController.position.maxScrollExtent / _scrollSpeed)
                .toInt()),
        curve: Curves.linear,
      );
    }
  }

  // Función para detener el desplazamiento
  void _stopScrolling() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset,
        duration: Duration.zero,
        curve: Curves.linear,
      );
    }
  }

  // Función para mostrar u ocultar acordes en la letra
  String _adjustLyricsForChords() {
    if (!_showChords) {
      final regex = RegExp(r'\(([A-Ga-g#b]+)\)');
      return widget.lyrics.replaceAll(regex, ''); // Eliminar acordes
    }
    return widget.lyrics;
  }

  // Función para alternar Play/Pausa
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startScrolling(); // Reanudar desplazamiento
      } else {
        _stopScrolling(); // Detener desplazamiento
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayedLyrics = _adjustLyricsForChords();

    return Scaffold(
      appBar: AppBar(
        title: Text("Teleprompter"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Contenido principal del teleprompter
          SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                displayedLyrics,
                style: TextStyle(
                  fontSize: 48,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
          ),
          // Barra de controles compacta
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Botón para alternar acordes
                  IconButton(
                    icon: Icon(
                      _showChords ? Icons.music_note : Icons.music_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showChords = !_showChords;
                      });
                    },
                  ),
                  // Botón para disminuir velocidad
                  IconButton(
                    icon: Icon(
                      Icons.remove,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_scrollSpeed > 10) _scrollSpeed -= 5;
                        _stopScrolling();
                        _startScrolling();
                      });
                    },
                  ),
                  // Botón de Play/Pausa
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  // Botón para aumentar velocidad
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_scrollSpeed < 100) _scrollSpeed += 5;
                        _stopScrolling();
                        _startScrolling();
                      });
                    },
                  ),
                  // Velocidad actual
                  Text(
                    "${_scrollSpeed.toInt()}x",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
