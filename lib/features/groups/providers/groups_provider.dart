import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/groups/models/group_model.dart';

part 'groups_provider.g.dart';

@riverpod
class Groups extends _$Groups {
  final _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<GroupModel>> build() {
    return _firestore.collection('groups').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> createGroup(
      String name, String description, String userId) async {
    try {
      final group = GroupModel(
        id: '',
        name: name,
        description: description,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('groups').add(group.toMap());
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
