import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final songSectionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('song_sections')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});
