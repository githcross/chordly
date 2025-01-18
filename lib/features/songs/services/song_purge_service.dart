import 'package:cloud_firestore/cloud_firestore.dart';

class SongPurgeService {
  static const int purgeDaysThreshold = 7;

  static Future<void> purgeSongs() async {
    try {
      final now = DateTime.now();
      final threshold = now.subtract(const Duration(days: purgeDaysThreshold));

      // Obtener canciones inactivas
      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where('isActive', isEqualTo: false)
          .get();

      // Filtrar y eliminar canciones que superan el umbral
      for (var doc in snapshot.docs) {
        final deletedAt = (doc.data()['deletedAt'] as Timestamp).toDate();
        if (deletedAt.isBefore(threshold)) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('Error durante la purga de canciones: $e');
    }
  }
}
