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
  final DateTime? deletedAt;
  final VideoReference? videoReference;

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
    this.deletedAt,
    this.videoReference,
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
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
      videoReference: map['videoReference'] != null
          ? VideoReference.fromMap(map['videoReference'])
          : null,
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
      'deletedAt': deletedAt,
      'videoReference': videoReference?.toMap(),
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
    if (this.status == 'publicado' && status == 'borrador') {
      throw Exception(
          'Una canción publicada no puede volver a estado borrador');
    }

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
      deletedAt: this.deletedAt,
      videoReference: this.videoReference,
    );
  }
}

class VideoReference {
  final String url;
  final String notes;

  VideoReference({
    required this.url,
    this.notes = '',
  });

  factory VideoReference.fromMap(Map<String, dynamic> map) {
    return VideoReference(
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'notes': notes,
    };
  }
}
