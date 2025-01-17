import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/groups/services/firestore_service.dart';
import 'package:chordly/features/groups/models/group_invitation_model.dart';
import 'package:chordly/features/groups/providers/groups_provider.dart';

part 'invitations_provider.g.dart';

@riverpod
Stream<List<GroupInvitation>> pendingInvitations(PendingInvitationsRef ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getPendingInvitations(user.uid);
}
