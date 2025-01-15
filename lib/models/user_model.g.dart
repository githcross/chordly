// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profilePicture: json['profilePicture'] as String?,
      lastLogin: DateTime.parse(json['lastLogin'] as String),
      joinedGroups: (json['joinedGroups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map(
                  (e) => NotificationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'name': instance.name,
      'profilePicture': instance.profilePicture,
      'lastLogin': instance.lastLogin.toIso8601String(),
      'joinedGroups': instance.joinedGroups,
      'notifications': instance.notifications,
    };

_$NotificationModelImpl _$$NotificationModelImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationModelImpl(
      type: json['type'] as String,
      groupId: json['groupId'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String? ?? 'unread',
    );

Map<String, dynamic> _$$NotificationModelImplToJson(
        _$NotificationModelImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'groupId': instance.groupId,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': instance.status,
    };
