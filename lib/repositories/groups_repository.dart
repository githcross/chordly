import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/models/group_model.dart';

part 'groups_repository.g.dart';

class GroupsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<GroupModel>> getUserGroups(String userId) async {
    try {
      final groupsRef = _firestore.collection('groups');
      final membershipsRef = _firestore.collection('groups_members');

      final memberships =
          await membershipsRef.where('userId', isEqualTo: userId).get();

      final groupIds = memberships.docs
          .map((doc) => doc.data()['groupId'] as String)
          .toList();

      if (groupIds.isEmpty) return [];

      final groupsSnapshot =
          await groupsRef.where(FieldPath.documentId, whereIn: groupIds).get();

      return groupsSnapshot.docs.map((doc) {
        final membership =
            memberships.docs.firstWhere((m) => m.data()['groupId'] == doc.id);

        return GroupModel.fromFirestore(doc, null).copyWith(
          userRole: membership.data()['role'] as String,
        );
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener grupos: $e');
    }
  }

  Future<void> createGroup(GroupModel group) async {
    try {
      final docRef = await _firestore.collection('groups').add(group.toJson());

      await _firestore.collection('groups_members').add({
        'groupId': docRef.id,
        'userId': group.createdBy,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al crear grupo: $e');
    }
  }
}

@riverpod
GroupsRepository groupsRepository(GroupsRepositoryRef ref) {
  return GroupsRepository();
}
