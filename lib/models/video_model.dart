import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_model.freezed.dart';
part 'video_model.g.dart';

@freezed
class VideoModel with _$VideoModel {
  const factory VideoModel({
    required String id,
    required String groupId,
    required String userId,
    required String title,
    required String description,
    required String videoUrl,
    required String thumbnailUrl,
    @Default(0) int likes,
    @Default(0) int views,
    @Default([]) List<String> likedBy,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _VideoModel;

  factory VideoModel.fromJson(Map<String, dynamic> json) =>
      _$VideoModelFromJson(json);

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoModel.fromJson({
      'id': doc.id,
      ...data,
    });
  }
}
