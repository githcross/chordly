import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class VideoService {
  Future<void> saveYoutubeVideo({
    required String groupId,
    required String videoId,
    required String description,
    required String originalUrl,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('videos')
        .add({
      'videoId': videoId,
      'originalUrl': originalUrl,
      'description': description,
      'type': 'youtube',
      'likes': 0,
      'views': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
