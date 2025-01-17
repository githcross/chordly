import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final songsCountProvider = StreamProvider.family<int, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('songs')
      .where('groupId', isEqualTo: groupId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.size);
});
