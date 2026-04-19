class DiscoverSong {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? previewUrl; // 30-sec mp3 from iTunes
  final String? artworkUrl;
  final String? genre;

  const DiscoverSong({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.previewUrl,
    this.artworkUrl,
    this.genre,
  });

  factory DiscoverSong.fromItunes(Map<String, dynamic> json) {
    // Upgrade artwork to higher resolution (100x100 → 300x300).
    final rawArt = json['artworkUrl100'] as String?;
    final artwork = rawArt?.replaceAll('100x100', '300x300');

    return DiscoverSong(
      id: (json['trackId'] as int).toString(),
      title: (json['trackName'] as String?) ?? 'Unknown',
      artist: (json['artistName'] as String?) ?? 'Unknown Artist',
      album: json['collectionName'] as String?,
      previewUrl: json['previewUrl'] as String?,
      artworkUrl: artwork,
      genre: json['primaryGenreName'] as String?,
    );
  }
}