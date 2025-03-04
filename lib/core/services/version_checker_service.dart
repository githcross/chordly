import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final versionCheckerProvider = Provider<VersionCheckerService>((ref) {
  return VersionCheckerService(FirebaseFirestore.instance);
});

class VersionCheckerService {
  final FirebaseFirestore _firestore;

  VersionCheckerService(this._firestore);

  Future<Map<String, dynamic>> getUpdateConfig() async {
    try {
      print('>>> Obteniendo configuración de Firestore');
      final doc =
          await _firestore.doc('app_status/config/update/current').get();
      print('<<< Datos obtenidos: ${doc.data()}');
      return doc.data() ?? {};
    } catch (e) {
      print('!!! Error obteniendo configuración: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getMaintenanceConfig() async {
    try {
      final doc =
          await _firestore.doc('app_status/config/maintenance/current').get();
      return doc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  bool needsUpdate(String currentVersion, String remoteVersion) {
    final currentParts =
        currentVersion.split('+').first.split('.').map(int.parse).toList();
    final remoteParts =
        remoteVersion.split('+').first.split('.').map(int.parse).toList();

    for (int i = 0; i < remoteParts.length; i++) {
      if (currentParts.length <= i) return true;
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}
