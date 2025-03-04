import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final updateSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .doc('app_status/config/updates/current')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? {});
});
