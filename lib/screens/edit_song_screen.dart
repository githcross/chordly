import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

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
  String _access = 'public'; // Inicializado con un valor predeterminado
  late String _userId; // Guardar el userId de la canción
  List<String> _tags = [];
  bool _isEditable =
      false; // Bandera para habilitar/deshabilitar el campo de acceso
  bool _isDataLoaded = false; // Indicador de si los datos han sido cargados

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _lyricController = TextEditingController();
    _tagsController = TextEditingController();
    _baseKeyController = TextEditingController();
    _language = 'Español';
    _fetchSongData();
    _fetchCommunitiesWithSong(); // Añadir esta línea para obtener las comunidades
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

      // Comparar el userId de la canción con el uid del usuario logueado
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
                  decoration: InputDecoration(labelText: 'Clave Base'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una clave base';
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
