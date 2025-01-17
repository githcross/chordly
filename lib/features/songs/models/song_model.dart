import 'package:cloud_firestore/cloud_firestore.dart';

class SongModel {
  final String id;
  final String title;
  final String author;
  final String lyrics;
  final String baseKey;
  final List<String> tags;
  final int tempo;
  final String duration;
  final String status;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final String groupId;
  final List<String> playlists;
  final bool isActive;

  SongModel({
    required this.id,
    required this.title,
    required this.author,
    required this.lyrics,
    required this.baseKey,
    required this.tags,
    required this.tempo,
    required this.duration,
    required this.status,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.groupId,
    required this.playlists,
    this.isActive = true,
  });

  factory SongModel.fromMap(String id, Map<String, dynamic> map) {
    return SongModel(
      id: id,
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      lyrics: map['lyrics'] ?? '',
      baseKey: map['baseKey'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      tempo: map['tempo'] ?? 0,
      duration: map['duration'] ?? '00:00',
      status: map['status'] ?? 'borrador',
      createdBy: map['createdBy'] ?? '',
      creatorName: map['creatorName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      groupId: map['groupId'] ?? '',
      playlists: List<String>.from(map['playlists'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'lyrics': lyrics,
      'baseKey': baseKey,
      'tags': tags,
      'tempo': tempo,
      'duration': duration,
      'status': status,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'groupId': groupId,
      'playlists': playlists,
      'isActive': isActive,
    };
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? author,
    String? lyrics,
    String? baseKey,
    List<String>? tags,
    int? tempo,
    String? duration,
    String? status,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    String? groupId,
    List<String>? playlists,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      lyrics: lyrics ?? this.lyrics,
      baseKey: baseKey ?? this.baseKey,
      tags: tags ?? this.tags,
      tempo: tempo ?? this.tempo,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
      playlists: playlists ?? this.playlists,
      isActive: this.isActive,
    );
  }
}
