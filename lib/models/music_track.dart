class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArt;
  final String url;
  final String service;
  final String? previewUrl;
  final String? albumArtUrl;
  final String serviceType; // 'spotify', 'apple', 'soundcloud'
  final List<String> genres;
  final int durationMs;
  final DateTime? releaseDate;
  final bool explicit;
  final int popularity; // 0-100

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArt,
    required this.url,
    required this.service,
    this.previewUrl,
    this.albumArtUrl,
    required this.serviceType,
    required this.genres,
    required this.durationMs,
    this.releaseDate,
    this.explicit = false,
    this.popularity = 50,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'] ?? '',
      albumArt: json['album_art'] ?? '',
      url: json['url'],
      service: json['service'],
      previewUrl: json['preview_url'],
      albumArtUrl: json['album_art_url'],
      serviceType: json['service_type'],
      genres: List<String>.from(json['genres'] ?? []),
      durationMs: json['duration_ms'] ?? 0,
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : null,
      explicit: json['explicit'] ?? false,
      popularity: json['popularity'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'album_art': albumArt,
      'url': url,
      'service': service,
      'preview_url': previewUrl,
      'album_art_url': albumArtUrl,
      'service_type': serviceType,
      'genres': genres,
      'duration_ms': durationMs,
      'release_date': releaseDate?.toIso8601String(),
      'explicit': explicit,
      'popularity': popularity,
    };
  }

  // Create sample tracks for testing
  static MusicTrack sampleTrack({
    String serviceType = 'spotify',
  }) {
    return MusicTrack(
      id: 'sample_track_id',
      title: 'Sample Track',
      artist: 'Sample Artist',
      album: 'Sample Album',
      albumArt: 'https://i.scdn.co/image/sample',
      url: 'https://open.spotify.com/track/sample',
      service: 'spotify',
      previewUrl: 'https://p.scdn.co/mp3-preview/sample',
      albumArtUrl: 'https://i.scdn.co/image/sample',
      serviceType: serviceType,
      genres: ['pop', 'electronic'],
      durationMs: 210000, // 3:30
      releaseDate: DateTime(2023, 1, 1),
      explicit: false,
      popularity: 75,
    );
  }
  
  // Helper method to format duration
  String get formattedDuration {
    final minutes = (durationMs / 60000).floor();
    final seconds = ((durationMs % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Helper method to get the primary genre
  String get primaryGenre {
    if (genres.isEmpty) return 'Unknown';
    return genres.first;
  }
  
  // Helper to get formatted artist and album text
  String get artistAndAlbum {
    if (album.isNotEmpty) {
      return '$artist • $album';
    }
    return artist;
  }
  
  // Helper to get service type icon
  String get serviceIcon {
    switch (serviceType.toLowerCase()) {
      case 'spotify':
        return 'assets/images/icons/spotify_icon.png';
      case 'apple':
        return 'assets/images/icons/apple_music_icon.png';
      case 'soundcloud':
        return 'assets/images/icons/soundcloud_icon.png';
      default:
        return 'assets/images/icons/music_icon.png';
    }
  }

  // Helper to generate pin data
  Map<String, dynamic> toPinData({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
  }) {
    return {
      'title': title,
      'description': description,
      'location': {
        'type': 'Point',
        'coordinates': [longitude, latitude]
      },
      'track_title': this.title,
      'track_artist': this.artist, 
      'album': this.album,
      'track_url': this.url,
      'service': this.service,
    };
  }
} 