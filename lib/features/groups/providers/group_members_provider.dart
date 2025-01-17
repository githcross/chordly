import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/features/groups/models/group_membership.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';

part 'group_members_provider.g.dart';

@riverpod
Stream<List<GroupMembership>> groupMembers(
    GroupMembersRef ref, String groupId) {
  return ref.watch(firestoreServiceProvider).getGroupMembers(groupId);
}
