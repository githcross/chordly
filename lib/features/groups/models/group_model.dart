import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum GroupRole {
  admin,
  editor,
  member;

  Color get color {
    switch (this) {
      case GroupRole.admin:
        return Colors.red;
      case GroupRole.editor:
        return Colors.green;
      case GroupRole.member:
        return Colors.blue;
    }
  }
}

class GroupMember {
  final String userId;
  final GroupRole role;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      userId: map['userId'] ?? '',
      role: GroupRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => GroupRole.member,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    final createdAtData = map['createdAt'];
    late final DateTime createdAt;

    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else if (createdAtData is String) {
      createdAt = DateTime.parse(createdAtData);
    } else {
      createdAt = DateTime.now(); // valor por defecto
    }

    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      createdBy: map['createdBy'] ?? '',
      createdAt: createdAt,
    );
  }
}
