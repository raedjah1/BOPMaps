class User {
  final int id;
  final String username;
  final String email;
  final String? profilePicUrl;
  final String? bio;
  final bool isVerified;
  final List<String> favoriteGenres;
  final Map<String, bool> connectedServices;
  final DateTime createdAt;
  final DateTime? lastActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePicUrl,
    this.bio,
    required this.isVerified,
    required this.favoriteGenres,
    required this.connectedServices,
    required this.createdAt,
    this.lastActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      profilePicUrl: json['profile_pic_url'],
      bio: json['bio'],
      isVerified: json['is_verified'] ?? false,
      favoriteGenres: List<String>.from(json['favorite_genres'] ?? []),
      connectedServices: {
        'spotify': json['spotify_connected'] ?? false,
        'apple_music': json['apple_music_connected'] ?? false,
        'soundcloud': json['soundcloud_connected'] ?? false,
      },
      createdAt: DateTime.parse(json['created_at']),
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profile_pic_url': profilePicUrl,
      'bio': bio,
      'is_verified': isVerified,
      'favorite_genres': favoriteGenres,
      'spotify_connected': connectedServices['spotify'],
      'apple_music_connected': connectedServices['apple_music'],
      'soundcloud_connected': connectedServices['soundcloud'],
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive?.toIso8601String(),
    };
  }

  // Create a copy of this user with updated fields
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? profilePicUrl,
    String? bio,
    bool? isVerified,
    List<String>? favoriteGenres,
    Map<String, bool>? connectedServices,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      connectedServices: connectedServices ?? this.connectedServices,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
  
  // Checks if user has connected a specific music service
  bool hasConnectedService(String service) {
    return connectedServices[service] ?? false;
  }
  
  // Returns the user's display name (username or first part of email)
  String get displayName {
    if (username.isNotEmpty) return username;
    // Extract name from email (e.g., "john" from "john@example.com")
    return email.split('@').first;
  }
  
  // Check if two users are the same (by ID)
  bool isSameUser(User other) {
    return id == other.id;
  }
} 