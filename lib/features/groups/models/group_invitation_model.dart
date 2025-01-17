import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected'

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.createdAt,
    required this.status,
  });

  factory GroupInvitation.fromMap(String id, Map<String, dynamic> map) {
    return GroupInvitation(
      id: id,
      groupId: map['group_id'],
      groupName: map['group_name'],
      fromUserId: map['from_user_id'],
      fromUserName: map['from_user_name'],
      toUserId: map['to_user_id'],
      createdAt: (map['created_at'] as Timestamp).toDate(),
      status: map['status'],
    );
  }
}
