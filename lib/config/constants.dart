import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Server API endpoints
  static String get baseApiUrl {
    // Make this resilient to missing dotenv by providing a fallback
    try {
      return dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api';
    } catch (e) {
      // If dotenv is not initialized, return default
      return 'http://127.0.0.1:8000/api';
    }
  }
  
  // Main API sections
  static const String usersAuthBase = '/users/auth';
  static const String musicBase = '/music';
  static const String pinsBase = '/pins';
  static const String profilesBase = '/profiles';
  
  // For backwards compatibility with existing code
  static const String authEndpoint = '/users/auth';
  static const String usersEndpoint = '/users';
  static const String pinsEndpoint = '/pins';
  
  // Authentication endpoints
  static const String loginEndpoint = '$usersAuthBase/token/';
  static const String refreshEndpoint = '$usersAuthBase/token/refresh/';
  static const String logoutEndpoint = '$usersAuthBase/logout/';
  static const String registerEndpoint = '$usersAuthBase/register/';
  static const String verifyEndpoint = '$usersAuthBase/verify/';
  
  // User endpoints
  static const String userProfileEndpoint = '/users/me/';
  static const String userSettingsEndpoint = '/users/settings/';
  
  // Django Music service endpoints
  static const String spotifyAuthEndpoint = '$musicBase/auth/spotify/';
  static const String spotifyCallbackEndpoint = '$musicBase/auth/spotify/callback/';
  static const String spotifyCallbackHandlerEndpoint = '$musicBase/auth/callback/';
  static const String connectedServicesEndpoint = '$musicBase/connected_services/';
  
  // Pin endpoints
  static const String allPinsEndpoint = '$pinsBase/';
  static const String nearbyPinsEndpoint = '$pinsBase/nearby/';
  static const String userPinsEndpoint = '$pinsBase/user/';
  static const String createPinEndpoint = '$pinsBase/create/';
  
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
  
  // ===== SPOTIFY API CONFIGURATION =====
  // Spotify API Constants
  static const String spotifyApiBaseUrl = 'https://api.spotify.com/v1';
  static const String spotifyAuthBaseUrl = 'https://accounts.spotify.com';
  static const String spotifyAuthUrl = '$spotifyAuthBaseUrl/authorize';
  static const String spotifyTokenUrl = '$spotifyAuthBaseUrl/api/token';
  
  static String get spotifyClientId {
    try {
      return dotenv.env['SPOTIFY_CLIENT_ID'] ?? 'placeholder_spotify_client_id';
    } catch (e) {
      return 'placeholder_spotify_client_id';
    }
  }
  
  static String get spotifyClientSecret {
    try {
      return dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? 'placeholder_spotify_client_secret';
    } catch (e) {
      return 'placeholder_spotify_client_secret';
    }
  }
  
  static String get spotifyRedirectUri {
    try {
      return dotenv.env['SPOTIFY_REDIRECT_URI'] ?? 'http://127.0.0.1:8000/api/music/callback';
    } catch (e) {
      return 'http://127.0.0.1:8000/api/music/callback';
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