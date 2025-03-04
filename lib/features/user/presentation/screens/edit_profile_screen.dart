import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditProfileScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedImage;
  final _bioController = TextEditingController();

  void _selectImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image.path;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(authProvider).currentUser!;
    _nameController.text = currentUser.displayName;
    _bioController.text = currentUser.biography ?? '';
    _selectedImage = currentUser.photoURL;
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the existing code)
  }

  void _handleUpdateProfile() async {
    try {
      if (_nameController.text.isEmpty || _bioController.text.isEmpty) {
        throw 'Nombre y biografía son requeridos';
      }

      await ref.read(userServiceProvider).updateProfile(
            displayName: _nameController.text,
            photoURL: _selectedImage ?? '',
            biography: _bioController.text,
          );

      // Actualizar UI
      if (mounted) {
        await ref.read(authProvider.notifier).refreshUser();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
