import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API endpoints
  static String get baseApiUrl {
    // Make this resilient to missing dotenv by providing a fallback
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://api.bopmaps.com';
    } catch (e) {
      // If dotenv is not initialized, return default
      return 'https://api.bopmaps.com';
    }
  }
  
  static const String authEndpoint = '/auth';
  static const String pinsEndpoint = '/pins';
  static const String usersEndpoint = '/users';
  static const String musicEndpoint = '/music';
  
  // Map settings
  static const double defaultZoom = 15.0;
  static const double maxZoom = 20.0;
  static const double minZoom = 10.0;
  static const double defaultPitch = 45.0; // For 3D-like effect
  
  // Default location (San Francisco) if user location is not available
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;
  
  // Pin settings
  static const double pinDiscoveryRadius = 100.0; // in meters
  static const Map<String, double> pinSizeByRarity = {
    'common': 60.0,
    'uncommon': 70.0,
    'rare': 80.0,
    'epic': 90.0,
    'legendary': 100.0,
  };
  
  // Authentication
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const int tokenExpiryDays = 30;
  
  // Media
  static const int maxAudioPreviewDuration = 30; // in seconds
  static const int maxPinDescriptionLength = 200; // characters
  
  // Music services
  static String get spotifyClientId {
    try {
      return dotenv.env['SPOTIFY_CLIENT_ID'] ?? 'placeholder_spotify_client_id';
    } catch (e) {
      return 'placeholder_spotify_client_id';
    }
  }
  
  static String get spotifyRedirectUri {
    try {
      return dotenv.env['SPOTIFY_REDIRECT_URI'] ?? 'com.bopmaps://callback';
    } catch (e) {
      return 'com.bopmaps://callback';
    }
  }
  
  static List<String> get spotifyScopes => [
    'user-read-private',
    'user-read-email',
    'user-library-read',
    'user-top-read',
    'streaming',
  ];
  
  // Mapbox
  static String get mapboxAccessToken {
    try {
      return dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? 'placeholder_mapbox_token';
    } catch (e) {
      return 'placeholder_mapbox_token';
    }
  }
  static const String mapboxStyleUrl = 'mapbox://styles/mapbox/dark-v10';
  
  // Animation durations
  static const Duration pinAnimationDuration = Duration(milliseconds: 1000);
  static const Duration mapTransitionDuration = Duration(milliseconds: 300);
  static const Duration auraEffectDuration = Duration(milliseconds: 2000);
  
  // Cache settings
  static const int maxCachedPins = 1000;
  static const Duration pinCacheExpiry = Duration(days: 7);
  
  // Social
  static const int maxFriendsPerPage = 20;
  static const int maxActivityItems = 50;
  
  // PIN rarity probabilities (%) - should add up to 100
  static const Map<String, int> rarityProbabilities = {
    'common': 60,
    'uncommon': 25,
    'rare': 10,
    'epic': 4,
    'legendary': 1,
  };
} 