import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
