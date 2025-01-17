import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/groups/models/group_membership.dart';
import 'package:chordly/features/groups/models/group_invitation_model.dart';
import 'package:chordly/features/groups/models/group_model.dart';

class FirestoreService {
  final firestore = FirebaseFirestore.instance;

  // Crear o actualizar usuario
  Future<void> createOrUpdateUser(
      String userId, Map<String, dynamic> userData) async {
    final userRef = firestore.collection('users').doc(userId);

    // Primero verificar si el usuario existe y obtener sus grupos actuales
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final existingGroups = userDoc.data()?['groups'] as List<dynamic>? ?? [];
      // Preservar los grupos existentes
      userData = {
        ...userData,
        'groups': existingGroups,
      };
    }

    // Actualizar o crear el documento
    await userRef.set(userData, SetOptions(merge: true));
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
    // 1. Agregar al usuario a la subcolección memberships del grupo
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

    // 2. Actualizar la lista de grupos del usuario
    await firestore.collection('users').doc(userId).update({
      'groups': FieldValue.arrayUnion([groupId])
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

  Stream<List<GroupMembership>> getGroupMembers(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .snapshots()
        .asyncMap((snapshot) async {
      final members = <GroupMembership>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String;

        // Obtener información del usuario
        final userDoc = await firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          members.add(
            GroupMembership(
              userId: userId,
              email: userData['email'] ?? '',
              displayName:
                  userData['displayName'] ?? userData['email'] ?? 'Usuario',
              profilePicture: userData['profilePicture'],
              role: data['role'] ?? 'member',
              isCreator: data['is_creator'] ?? false,
              joinedAt: (data['joined_at'] as Timestamp).toDate(),
            ),
          );
        }
      }
      return members;
    });
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final snapshot = await firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'email': doc.data()['email'] ?? '',
              'displayName': doc.data()['displayName'] ?? '',
              'profilePicture': doc.data()['profilePicture'],
            })
        .toList();
  }

  Future<void> inviteToGroup({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    await addMemberToGroup(
      groupId: groupId,
      userId: userId,
      role: role,
      isCreator: false,
    );
  }

  Stream<List<String>> getUserGroupIds(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return <String>[];
      final data = snapshot.data();
      return (data?['groups'] as List<dynamic>?)?.cast<String>() ?? [];
    });
  }

  // Enviar invitación
  Future<void> sendGroupInvitation({
    required String groupId,
    required String groupName,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) async {
    await firestore.collection('invitations').add({
      'group_id': groupId,
      'group_name': groupName,
      'from_user_id': fromUserId,
      'from_user_name': fromUserName,
      'to_user_id': toUserId,
      'created_at': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // Obtener invitaciones pendientes
  Stream<List<GroupInvitation>> getPendingInvitations(String userId) {
    return firestore
        .collection('invitations')
        .where('to_user_id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Responder a invitación
  Future<void> respondToInvitation({
    required String invitationId,
    required String response, // 'accepted' o 'rejected'
    required String userId,
    required String groupId,
  }) async {
    final batch = firestore.batch();

    // Actualizar estado de la invitación
    final invitationRef = firestore.collection('invitations').doc(invitationId);
    batch.update(invitationRef, {'status': response});

    // Si fue aceptada, agregar al usuario al grupo
    if (response == 'accepted') {
      await addMemberToGroup(
        groupId: groupId,
        userId: userId,
        role: GroupRole.member.name,
      );
    }

    await batch.commit();
  }

  // Abandonar grupo
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final batch = firestore.batch();

    // 1. Eliminar al usuario de la subcolección memberships del grupo
    final membershipRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId);
    batch.delete(membershipRef);

    // 2. Eliminar el groupId del array de grupos del usuario
    final userRef = firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'groups': FieldValue.arrayRemove([groupId])
    });

    await batch.commit();
  }
}
