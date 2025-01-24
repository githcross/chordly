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

  PlaylistSongItem({
    required this.songId,
    required this.order,
    required this.transposedKey,
    this.notes = '',
  });
}

enum PlaylistStatus {
  draft, // Borrador
  approved, // Aprobado
  completed // Completado
}
