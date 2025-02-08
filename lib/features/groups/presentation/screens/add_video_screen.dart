import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/services/video_service.dart';

class AddVideoScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddVideoScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends ConsumerState<AddVideoScreen> {
  File? _videoFile;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tags = <String>[];
  bool _isUploading = false;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });

      _videoController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, agrega un título')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Usuario no autenticado');

      final urls = await VideoService.uploadVideo(_videoFile!);

      final videoDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('videos')
          .add({
        'userId': user.uid,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'videoUrl': urls['videoUrl'],
        'thumbnailUrl': urls['thumbnailUrl'],
        'likes': 0,
        'views': 0,
        'likedBy': [],
        'tags': _tags,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video publicado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir el video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Video'),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _isUploading ? null : _uploadVideo,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Publicar'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_videoFile == null)
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_call, size: 64),
                        SizedBox(height: 16),
                        Text('Toca para seleccionar un video'),
                      ],
                    ),
                  ),
                ),
              )
            else if (_videoController?.value.isInitialized ?? false)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                    _isPlaying
                        ? _videoController?.play()
                        : _videoController?.pause();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    if (!_isPlaying)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
