import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/videos/presentation/screens/add_video_screen.dart';

class VideoFeedScreen extends ConsumerStatefulWidget {
  final String groupId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> videos;

  const VideoFeedScreen({
    super.key,
    required this.groupId,
    required this.videos,
  });

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> {
  late PageController _pageController;
  late List<YoutubePlayerController> _ytControllers;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _ytControllers = widget.videos.map((video) {
      final data = video.data();
      final controller = YoutubePlayerController(
        initialVideoId: data['videoId'],
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
          enableCaption: false,
          disableDragSeek: true,
          loop: false,
        ),
      );

      controller.addListener(() {
        if (controller.value.isReady && !controller.value.isPlaying) {
          controller.play();
        }
      });

      return controller;
    }).toList();

    print('Videos cargados: ${widget.videos.length}');
    _ytControllers.asMap().forEach((i, controller) {
      print('Controlador $i: ${controller.initialVideoId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 50, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              'Videos en Desarrollo\n¡Próximamente!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Estamos trabajando para traerte\nla mejor experiencia de videos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePageChange(int newIndex) {
    if (_currentPage < _ytControllers.length) {
      _ytControllers[_currentPage].pause();
    }
    _currentPage = newIndex;

    if (newIndex < _ytControllers.length) {
      _ytControllers[newIndex].play();
    }
  }

  Widget _buildVideoOverlay(Map<String, dynamic> video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video['description'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _openOriginalLink(video['originalUrl']),
          child: Text(
            'Ver en YouTube',
            style: TextStyle(
              color: Colors.blue[200],
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  void _openOriginalLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _navigateToAddVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVideoScreen(groupId: widget.groupId),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _ytControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  YoutubePlayerController _createYoutubeController(String videoId) {
    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        enableCaption: false,
        disableDragSeek: true,
        loop: false,
      ),
    );

    controller.addListener(() {
      if (controller.value.isReady && !controller.value.isPlaying) {
        controller.play();
      }
    });

    return controller;
  }
}
