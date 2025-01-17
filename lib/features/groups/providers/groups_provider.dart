import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';

part 'groups_provider.g.dart';

@riverpod
FirestoreService firestoreService(FirestoreServiceRef ref) {
  return FirestoreService();
}

@riverpod
class Groups extends _$Groups {
  @override
  Stream<List<GroupModel>> build() {
    return ref
        .watch(firestoreServiceProvider)
        .firestore
        .collection('groups')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> createGroup(
      String name, String description, String userId) async {
    try {
      final service = ref.read(firestoreServiceProvider);

      // 1. Crear el grupo
      final groupRef = await service.createGroup({
        'name': name,
        'description': description,
        'created_by': userId,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Agregar al creador como miembro admin
      await service.addMemberToGroup(
        groupId: groupRef.id,
        userId: userId,
        role: GroupRole.admin.name,
        isCreator: true,
      );
    } catch (e) {
      throw Exception('Error al crear el grupo: $e');
    }
  }
}

@riverpod
class FilteredGroups extends _$FilteredGroups {
  @override
  Stream<List<GroupModel>> build(String searchQuery) {
    final groups = ref.watch(groupsProvider.select((value) => value.value));

    if (groups == null) {
      return Stream.value([]);
    }

    return Stream.value(groups
        .where((group) =>
            group.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            group.description.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList());
  }
}
