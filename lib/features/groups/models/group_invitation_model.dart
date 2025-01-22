import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String fromUserId;
  final String toUserId;
  final String status;
  final DateTime createdAt;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  factory GroupInvitation.fromMap(String id, Map<String, dynamic> map) {
    return GroupInvitation(
      id: id,
      groupId: map['group_id'] ?? '',
      groupName: map['group_name'] ?? '',
      fromUserId: map['from_user_id'] ?? '',
      toUserId: map['to_user_id'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }
}
