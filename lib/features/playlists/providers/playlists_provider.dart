import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final playlistsCountProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('playlists')
      .where('groupId', isEqualTo: groupId)
      .snapshots()
      .map((snapshot) => snapshot.size);
});
