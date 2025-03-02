import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/videos/services/video_service.dart';

final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});
