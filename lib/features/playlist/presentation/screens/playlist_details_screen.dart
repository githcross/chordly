void _navigateToSongDetails(int index) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SongDetailsScreen(
        songId: _playlistSongs[index],
        playlistSongs: _playlistSongs,
        currentIndex: index,
        fromPlaylist: true,
      ),
    ),
  );
}
