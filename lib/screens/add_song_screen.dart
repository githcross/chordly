import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class AddSongScreen extends StatefulWidget {
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
  late String _language;
  String _access = 'public';
  List<String> _tags = [];
  bool _isEditable = true;

  String? _creatorName;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _lyricController = TextEditingController();
    _tagsController = TextEditingController();
    _baseKeyController = TextEditingController();
    _language = 'Español';

    _getCreatorName();
  }

  // Obtener el nombre del creador dependiendo del proveedor de autenticación
  void _getCreatorName() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Verificar el proveedor de autenticación
        final userProvider = user.providerData.first.providerId;

        // Si el proveedor es Google, usar directamente el nombre del usuario
        if (userProvider == 'google.com') {
          setState(() {
            _creatorName = user.displayName ?? 'Desconocido';
          });
        }
        // Si el proveedor es Facebook, usar directamente el nombre del usuario
        else if (userProvider == 'facebook.com') {
          setState(() {
            _creatorName = user.displayName ?? 'Desconocido';
          });
        } else {
          // Para otros proveedores, buscar el nombre en Firestore
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
          _creatorName = 'Desconocido'; // Valor por defecto en caso de error
        });
      }
    }
  }

  // Guardar la canción en Firestore
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
    final timestamp = Timestamp.now();

    if (user != null &&
        title.isNotEmpty &&
        author.isNotEmpty &&
        lyric.isNotEmpty &&
        baseKey.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('songs').add({
          'title': title,
          'author': author,
          'language': _language,
          'tags': tags,
          'lyric': lyric,
          'baseKey': baseKey,
          'timestamp': timestamp,
          'userId': user.uid,
          'creatorName': _creatorName ?? 'Desconocido', // Nombre del creador
          'access': _access,
          'isArchived': false,
        });
        Navigator.pop(context); // Regresar a la pantalla anterior
      } catch (e) {
        _showErrorSnackBar('Error al guardar la canción.');
      }
    } else {
      _showErrorSnackBar('Por favor, completa todos los campos.');
    }
  }

  // Mostrar mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                // Título
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
                // Autor
                TextFormField(
                  controller: _authorController,
                  decoration: InputDecoration(labelText: 'Autor'),
                ),
                // Etiquetas
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(labelText: 'Etiquetas'),
                  onChanged: (value) {
                    _tags = value.split(',').map((e) => e.trim()).toList();
                  },
                ),
                // Clave Base
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
                // Idioma
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
                // Acceso
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
                // Letra
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
