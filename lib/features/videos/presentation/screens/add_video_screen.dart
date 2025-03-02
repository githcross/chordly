import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:chordly/features/videos/services/video_service.dart';
import 'package:chordly/features/videos/providers/video_service_provider.dart';

class AddVideoScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddVideoScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends ConsumerState<AddVideoScreen> {
  final _youtubeController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Short de YouTube')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _youtubeController,
              decoration: const InputDecoration(
                labelText: 'URL de YouTube Shorts',
                hintText: 'Ej: https://youtube.com/shorts/VIDEO_ID',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Agrega una descripción opcional...',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _saveVideo,
              icon: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.add_link),
              label: Text(_isProcessing ? 'Guardando...' : 'Agregar Short'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveVideo() async {
    final videoUrl = _youtubeController.text;
    if (!videoUrl.contains('youtube.com/shorts/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de YouTube Shorts inválida')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final videoService = ref.read(videoServiceProvider);
      await videoService.saveYoutubeVideo(
        groupId: widget.groupId,
        videoId: YoutubePlayer.convertUrlToId(videoUrl)!,
        description: _descriptionController.text,
        originalUrl: videoUrl,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
