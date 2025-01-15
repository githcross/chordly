import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String name,
    String? profilePicture,
    required DateTime lastLogin,
    @Default([]) List<String> joinedGroups,
    @Default([]) List<NotificationModel> notifications,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    return UserModel.fromJson({
      ...data,
      'id': snapshot.id,
    });
  }
}

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String type,
    required String groupId,
    required String message,
    required DateTime timestamp,
    @Default('unread') String status,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
