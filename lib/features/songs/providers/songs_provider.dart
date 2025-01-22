import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';

final songsCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, groupId) {
  final user = ref.read(authProvider).value;
  if (user == null) return Stream.value(0);

  // Query para canciones publicadas
  final publishedQuery = FirebaseFirestore.instance
      .collection('songs')
      .where('groupId', isEqualTo: groupId)
      .where('isActive', isEqualTo: true)
      .where('status', isEqualTo: 'publicado');

  // Query para borradores del usuario actual
  final draftsQuery = FirebaseFirestore.instance
      .collection('songs')
      .where('groupId', isEqualTo: groupId)
      .where('isActive', isEqualTo: true)
      .where('status', isEqualTo: 'borrador')
      .where('createdBy', isEqualTo: user.uid);

  // Query para canciones archivadas del usuario actual
  final archivedQuery = FirebaseFirestore.instance
      .collection('songs')
      .where('groupId', isEqualTo: groupId)
      .where('isActive', isEqualTo: false)
      .where('createdBy', isEqualTo: user.uid);

  // Observar cambios en el usuario
  ref.listen(authProvider, (previous, next) {
    ref.invalidateSelf();
  });

  return Rx.combineLatest3(
    publishedQuery.snapshots(),
    draftsQuery.snapshots(),
    archivedQuery.snapshots(),
    (QuerySnapshot published, QuerySnapshot drafts, QuerySnapshot archived) {
      final allDocs = [...published.docs, ...drafts.docs, ...archived.docs];
      return allDocs.length;
    },
  );
});
