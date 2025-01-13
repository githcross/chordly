import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

const List<String> kChordKeys = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B'
];

class EditSongScreen extends StatefulWidget {
  final String songId;

  EditSongScreen({required this.songId});

  @override
  _EditSongScreenState createState() => _EditSongScreenState();
}

class _EditSongScreenState extends State<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _lyricController;
  late TextEditingController _tagsController;
  late TextEditingController _baseKeyController;
  late String _language;
  late String _tempo; // Agregado para tempo
  late String _duration; // Agregado para duration
  String _access = 'public'; // Inicializado con un valor predeterminado
  late String _userId; // Guardar el userId de la canción
  List<String> _tags = [];
  bool _isEditable =
      false; // Bandera para habilitar/deshabilitar el campo de acceso
  bool _isDataLoaded = false; // Indicador de si los datos han sido cargados
  List<String> _chordKeys = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _lyricController = TextEditingController();
    _tagsController = TextEditingController();
    _baseKeyController = TextEditingController();
    _language = 'Español';
    _tempo = '120'; // Valor inicial para tempo
    _duration = '04:00'; // Valor inicial para duration (en formato mm:ss)
    _fetchSongData();
    _fetchCommunitiesWithSong(); // Añadir esta línea para obtener las comunidades
    _loadChordKeys(); // Agregar esta línea
  }

  // Recuperar los datos de la canción desde Firebase
  void _fetchSongData() async {
    DocumentSnapshot songDoc = await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get();
    if (songDoc.exists) {
      var song = songDoc.data() as Map<String, dynamic>;
      _titleController.text = song['title'];
      _authorController.text = song['author'];
      _lyricController.text = song['lyric'];
      _tags = List<String>.from(song['tags']);
      _tagsController.text = _tags.join(', ');
      _language = song['language'];
      _baseKeyController.text = song['baseKey'] ?? '';
      _access = song['access'] ??
          'public'; // Asegurarse de que _access tenga un valor
      _userId = song['userId']; // Guardar el userId de la canción
      _tempo = song['tempo'] ?? '120'; // Cargar el valor de tempo
      _duration = song['duration'] ??
          '04:00'; // Cargar el valor de duration en formato mm:ss

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == _userId) {
        setState(() {
          _isEditable = true; // Si el usuario es el creador, habilitar edición
        });
      }

      setState(() {
        _isDataLoaded = true; // Marcar como cargado
      });
    }
  }

  // Guardar los cambios en Firebase
  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Actualizar la canción en la colección songs
        await FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.songId)
            .update({
          'title': _titleController.text,
          'author': _authorController.text,
          'lyric': _lyricController.text,
          'tags': _tags,
          'language': _language,
          'baseKey': _baseKeyController.text,
          'access': _access,
          'tempo': _tempo, // Guardar tempo
          'duration': _duration, // Guardar duration
        });

        // 2. Obtener todas las comunidades que tienen esta canción
        final communitiesQuery =
            await FirebaseFirestore.instance.collection('communities').get();

        // 3. Actualizar la canción en cada comunidad que la contenga
        for (var doc in communitiesQuery.docs) {
          var songs =
              List<Map<String, dynamic>>.from(doc.data()['songs'] ?? []);
          var songIndex = songs.indexWhere((s) => s['songId'] == widget.songId);

          if (songIndex != -1) {
            // Actualizar solo los campos necesarios en communities
            songs[songIndex] = {
              'songId': widget.songId,
              'title': _titleController.text,
              'author': _authorController.text,
              'baseKey': _baseKeyController.text,
              'tempo': _tempo, // Guardar tempo en la comunidad
              'duration': _duration, // Guardar duration en la comunidad
            };

            await doc.reference.update({'songs': songs});
          }
        }

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canción actualizada exitosamente')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la canción: $e')),
        );
      }
    }
  }

  void _fetchCommunitiesWithSong() async {
    final songRef = FirebaseFirestore.instance
        .collection('communities')
        .where('songs', arrayContains: {'songId': widget.songId});

    final querySnapshot = await songRef.get();
    // Puedes usar querySnapshot.docs para acceder a las comunidades
    // que contienen esta canción si lo necesitas más adelante
  }

  void _loadChordKeys() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('notes').doc('chords');

      var snapshot = await docRef.get();

      if (!snapshot.exists) {
        // Si el documento no existe, lo creamos con el array de acordes
        await docRef.set({
          'chords': [
            'C',
            'C#',
            'D',
            'Eb',
            'E',
            'F',
            'F#',
            'G',
            'G#',
            'A',
            'Bb',
            'B',
            'Cm',
            'C#m',
            'Dm',
            'Ebm',
            'Em',
            'Fm',
            'F#m',
            'Gm',
            'G#m',
            'Am',
            'Bbm',
            'Bm',
            'C7',
            'C#7',
            'D7',
            'Eb7',
            'E7',
            'F7',
            'F#7',
            'G7',
            'G#7',
            'A7',
            'Bb7',
            'B7',
            'Cm7',
            'C#m7',
            'Dm7',
            'Ebm7',
            'Em7',
            'Fm7',
            'F#m7',
            'Gm7',
            'G#m7',
            'Am7',
            'Bbm7',
            'Bm7'
          ]
        });
        snapshot = await docRef.get();
      }

      final data = snapshot.data();
      if (data != null && data['chords'] != null) {
        List<dynamic> chordsArray = data['chords'];
        List<String> chordsList = chordsArray.map((e) => e.toString()).toList();

        setState(() {
          _chordKeys = chordsList;
        });
      } else {
        setState(() {
          _chordKeys = kChordKeys;
        });
      }
    } catch (e) {
      print('Error al cargar los acordes: $e');
      setState(() {
        _chordKeys = kChordKeys;
      });
    }
  }

  void _selectBaseKey() async {
    if (_chordKeys.isEmpty) {
      print("No hay acordes disponibles");
      return;
    }

    final selectedKey = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Selecciona la clave base'),
        children: _chordKeys.map((key) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, key),
            child: Text(key),
          );
        }).toList(),
      ),
    );

    if (selectedKey != null) {
      setState(() {
        _baseKeyController.text = selectedKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar pantalla solo después de cargar los datos
    if (!_isDataLoaded) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Editar Canción"),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: kIconColor),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Título'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa un título';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _authorController,
                  decoration: InputDecoration(labelText: 'Autor'),
                ),
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(labelText: 'Etiquetas'),
                  onChanged: (value) {
                    _tags = value.split(',').map((e) => e.trim()).toList();
                  },
                ),
                TextFormField(
                  controller: _baseKeyController,
                  readOnly: true, // Hacer el campo de solo lectura
                  decoration: InputDecoration(
                    labelText: 'Clave Base',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.keyboard_arrow_down),
                      onPressed: _selectBaseKey,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona una clave base';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _language,
                  onChanged: (String? newValue) {
                    setState(() {
                      _language = newValue!;
                    });
                  },
                  items: <String>['Ingles', 'Español']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: InputDecoration(labelText: 'Idioma'),
                ),
                SizedBox(height: 16),
                // Campos para tempo y duración
                TextFormField(
                  controller: TextEditingController(text: _tempo),
                  decoration: InputDecoration(labelText: 'Tempo (BPM)'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _tempo = value;
                  },
                ),
                TextFormField(
                  controller: TextEditingController(
                      text: _duration.isEmpty ? '00:00' : _duration),
                  decoration: InputDecoration(
                    labelText: 'Duración (mm:ss)',
                    hintText: '00:00',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  onChanged: (value) {
                    String formatted = value.replaceAll(RegExp(r'[^0-9]'), '');

                    if (formatted.length > 4) {
                      formatted = formatted.substring(0, 4);
                    }

                    if (formatted.length >= 2) {
                      formatted = formatted.substring(0, 2) +
                          ':' +
                          (formatted.length > 2
                              ? formatted.substring(2)
                              : '00');
                    } else if (formatted.length > 0) {
                      formatted = formatted.padLeft(2, '0') + ':00';
                    } else {
                      formatted = '00:00';
                    }

                    if (formatted != value) {
                      _duration = formatted;
                      TextEditingController(text: formatted).value =
                          TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    } else {
                      _duration = value;
                    }
                  },
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[0-5][0-9]:[0-5][0-9]$').hasMatch(value)) {
                      return 'Formato inválido (mm:ss)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                // Mostrar campo acceso solo si es editable
                _isEditable
                    ? DropdownButtonFormField<String>(
                        value: _access,
                        onChanged: (String? newValue) {
                          setState(() {
                            _access = newValue!;
                          });
                        },
                        items: <String>['public', 'private']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child:
                                Text(value == 'public' ? 'Público' : 'Privado'),
                          );
                        }).toList(),
                        decoration: InputDecoration(labelText: 'Acceso'),
                      )
                    : TextFormField(
                        initialValue:
                            _access == 'public' ? 'Público' : 'Privado',
                        decoration: InputDecoration(
                          labelText: 'Acceso',
                          enabled: false,
                        ),
                      ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: TextFormField(
                    controller: _lyricController,
                    decoration: InputDecoration(labelText: 'Letra'),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
