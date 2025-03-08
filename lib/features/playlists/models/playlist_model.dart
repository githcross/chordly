class PlaylistModel {
  final String id;
  final String name;
  final String groupId;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final List<PlaylistSongItem> songs;
  final String notes;
  final PlaylistStatus status;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.groupId,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    required this.songs,
    this.notes = '',
    this.status = PlaylistStatus.draft,
  });
}

class PlaylistSongItem {
  final String songId;
  final int order;
  final String transposedKey;
  final String notes;
  final String duration;

  PlaylistSongItem({
    required this.songId,
    required this.order,
    required this.transposedKey,
    required this.notes,
    required this.duration,
  });

  PlaylistSongItem copyWith({
    String? songId,
    int? order,
    String? transposedKey,
    String? notes,
    String? duration,
  }) {
    return PlaylistSongItem(
      songId: songId ?? this.songId,
      order: order ?? this.order,
      transposedKey: transposedKey ?? this.transposedKey,
      notes: notes ?? this.notes,
      duration: duration ?? this.duration,
    );
  }
}

enum PlaylistStatus {
  draft, // Borrador
  approved, // Aprobado
  completed // Completado
}
