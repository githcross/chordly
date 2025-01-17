import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final firestore = FirebaseFirestore.instance;

  // Crear o actualizar usuario
  Future<void> createOrUpdateUser(
      String userId, Map<String, dynamic> userData) async {
    await firestore
        .collection('users')
        .doc(userId)
        .set(userData, SetOptions(merge: true));
  }

  // Crear un nuevo grupo
  Future<DocumentReference> createGroup(Map<String, dynamic> groupData) async {
    // 1. Crear el grupo
    final groupRef = await firestore.collection('groups').add(groupData);

    // 2. Crear la subcolección memberships
    await groupRef.collection('memberships').doc(); // Esto crea la subcolección

    return groupRef;
  }

  // Agregar miembro a un grupo
  Future<void> addMemberToGroup({
    required String groupId,
    required String userId,
    required String role,
    bool isCreator = false,
  }) async {
    final membershipRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId);

    await membershipRef.set({
      'user_id': userId,
      'role': role,
      'is_creator': isCreator,
      'joined_at': FieldValue.serverTimestamp(),
    });
  }

  // Obtener membresías de un usuario
  Stream<QuerySnapshot> getUserMemberships(String userId) {
    return firestore
        .collectionGroup('memberships')
        .where('user_id', isEqualTo: userId)
        .snapshots();
  }

  Future<String?> getUserRoleInGroup(String groupId, String userId) async {
    final memberDoc = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId)
        .get();

    if (memberDoc.exists) {
      return memberDoc.data()?['role'];
    }
    return null;
  }
}
