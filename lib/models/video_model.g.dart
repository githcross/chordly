// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VideoModelImpl _$$VideoModelImplFromJson(Map<String, dynamic> json) =>
    _$VideoModelImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$VideoModelImplToJson(_$VideoModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'videoUrl': instance.videoUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'likes': instance.likes,
      'views': instance.views,
      'likedBy': instance.likedBy,
      'tags': instance.tags,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'comments': instance.comments,
    };

_$CommentImpl _$$CommentImplFromJson(Map<String, dynamic> json) =>
    _$CommentImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userDisplayName: json['userDisplayName'] as String?,
      userProfilePicture: json['userProfilePicture'] as String?,
    );

Map<String, dynamic> _$$CommentImplToJson(_$CommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'text': instance.text,
      'timestamp': instance.timestamp.toIso8601String(),
      'userDisplayName': instance.userDisplayName,
      'userProfilePicture': instance.userProfilePicture,
    };
