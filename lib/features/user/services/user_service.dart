import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserService(this._firestore, this._auth);

  Future<void> updateProfile({
    required String displayName,
    required String profilePicture,
    required String biography,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) return;

    final currentData = doc.data() as Map<String, dynamic>;
    final updateData = <String, dynamic>{};

    if (displayName != currentData['displayName']) {
      updateData['displayName'] = displayName;
    }
    if (profilePicture != currentData['profilePicture']) {
      updateData['profilePicture'] = profilePicture;
    }
    if (biography != currentData['biography']) {
      updateData['biography'] = biography;
    }

    if (updateData.isNotEmpty) {
      await userDoc.update(updateData);
      await _updateUserTimestamp(user.uid);

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(profilePicture);

      await _auth.currentUser?.reload();
    }
  }

  Future<void> updateBiography(String biography) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'biography': biography,
    });

    await _updateUserTimestamp(user.uid);
  }

  Future<void> updateProfilePicture(String profilePicture) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'profilePicture': profilePicture,
    });

    await user.updatePhotoURL(profilePicture);
    await _updateUserTimestamp(user.uid);
  }

  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'displayName': newName,
      'updatedAt_user': FieldValue.serverTimestamp(),
    });

    await user.updateDisplayName(newName);
    await _updateUserTimestamp(user.uid);
  }

  Future<void> _updateUserTimestamp(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'updatedAt_user': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateRelatedGroupData(String userId) async {
    // Lógica para actualizar grupos y otros documentos relacionados
  }

  Future<void> _updateUserStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
