import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class AddSongScreen extends StatefulWidget {
  final String groupId;

  const AddSongScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  _AddSongScreenState createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _lyricController;
  late TextEditingController _tagsController;
  late TextEditingController _baseKeyController;
  late TextEditingController _tempoController;
  late TextEditingController _durationController;
  late String _language;
  String _access = 'public';
  List<String> _tags = [];
  bool _isEditable = true;

  String? _creatorName;

  List<String> _chordKeys = []; // Lista para guardar los acordes de Firestore

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _lyricController = TextEditingController();
    _tagsController = TextEditingController();
    _baseKeyController = TextEditingController();
    _tempoController = TextEditingController();
    _durationController = TextEditingController();
    _language = 'Español';

    _getCreatorName();
    _loadChordKeys(); // Cargar los acordes de Firestore al iniciar
  }

  void _getCreatorName() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userProvider = user.providerData.first.providerId;

        if (userProvider == 'google.com' || userProvider == 'facebook.com') {
          setState(() {
            _creatorName = user.displayName ?? 'Desconocido';
          });
        } else {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userSnapshot.exists) {
            setState(() {
              _creatorName = userSnapshot.data()?['name'] ?? 'Desconocido';
            });
          }
        }
      } catch (e) {
        print('Error al obtener el nombre del creador: $e');
        setState(() {
          _creatorName = 'Desconocido';
        });
      }
    }
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
        // Obtener el documento recién creado
        snapshot = await docRef.get();
      }

      final data = snapshot.data();
      if (data != null && data['chords'] != null) {
        List<dynamic> chordsArray = data['chords'];
        print('Array de acordes: $chordsArray');

        List<String> chordsList = chordsArray.map((e) => e.toString()).toList();
        print('Lista final de acordes: $chordsList');

        setState(() {
          _chordKeys = chordsList;
        });
      } else {
        print('El campo chords es nulo');
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

  void _saveSong() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final lyric = _lyricController.text.trim();
    final baseKey = _baseKeyController.text.trim();
    final tempo = int.tryParse(_tempoController.text.trim()) ?? 120;
    final duration = _durationController.text.trim();
    final timestamp = Timestamp.now();

    if (user != null &&
        title.isNotEmpty &&
        author.isNotEmpty &&
        lyric.isNotEmpty &&
        baseKey.isNotEmpty) {
      try {
        final docRef =
            await FirebaseFirestore.instance.collection('songs').add({
          'title': title,
          'author': author,
          'language': _language,
          'tags': tags,
          'lyric': lyric,
          'baseKey': baseKey,
          'tempo': tempo,
          'duration': duration,
          'timestamp': timestamp,
          'userId': user.uid,
          'creatorName': _creatorName ?? 'Desconocido',
          'access': _access,
          'isArchived': false,
          'groupId': widget.groupId,
        });

        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.groupId)
            .update({
          'songs': FieldValue.arrayUnion([
            {
              'songId': docRef.id,
              'title': title,
              'author': author,
              'baseKey': baseKey,
            }
          ])
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canción guardada exitosamente')),
        );
      } catch (e) {
        _showErrorSnackBar('Error al guardar la canción: $e');
      }
    } else {
      _showErrorSnackBar('Por favor, completa todos los campos.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Agregar Canción"),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: kIconColor),
            onPressed: _saveSong,
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
                  readOnly: true,
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
                TextFormField(
                  controller: _tempoController,
                  decoration: InputDecoration(labelText: 'Tempo (BPM)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el tempo';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: TextEditingController(
                      text: _durationController.text.isEmpty
                          ? '00:00'
                          : _durationController.text),
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
                      _durationController.text = formatted;
                      _durationController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    } else {
                      _durationController.text = value;
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
                DropdownButtonFormField<String>(
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
                      child: Text(value == 'public' ? 'Público' : 'Privado'),
                    );
                  }).toList(),
                  decoration: InputDecoration(labelText: 'Acceso'),
                ),
                SizedBox(height: 16),
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
  'B',
];
