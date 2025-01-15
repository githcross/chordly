import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/models/group_model.dart';
import 'package:chordly/repositories/groups_repository.dart';
import 'package:chordly/services/auth_service.dart';

part 'groups_provider.g.dart';

@riverpod
class Groups extends _$Groups {
  @override
  Future<List<GroupModel>> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const [];

    return ref.watch(groupsRepositoryProvider).getUserGroups(user.uid);
  }

  Future<void> createGroup(GroupModel group) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(groupsRepositoryProvider).createGroup(group);
      return ref.refresh(groupsProvider.future);
    });
  }
}

@riverpod
class GroupsSearch extends _$GroupsSearch {
  @override
  String build() => '';
}
