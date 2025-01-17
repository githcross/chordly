import 'package:chordly/features/groups/models/group_model.dart';

class GroupMembership {
  final String userId;
  final String email;
  final String displayName;
  final String? profilePicture;
  final String role;
  final bool isCreator;
  final DateTime joinedAt;

  GroupMembership({
    required this.userId,
    required this.email,
    required this.displayName,
    this.profilePicture,
    required this.role,
    required this.isCreator,
    required this.joinedAt,
  });
}
