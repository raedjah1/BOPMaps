import 'package:flutter/foundation.dart';
import '../services/api/django_auth_service.dart';
import '../services/music/spotify_auth_service.dart';

/// AuthManager provides a unified interface for authentication-related operations.
/// It demonstrates how to use both DjangoAuthService and SpotifyAuthService together.
class AuthManager {
  // Singleton pattern
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  // Services
  final DjangoAuthService _djangoAuthService = DjangoAuthService();
  final SpotifyAuthService _spotifyAuthService = SpotifyAuthService();

  // Check if user is logged in to the app
  Future<bool> isUserLoggedIn() async {
    return await _djangoAuthService.isAuthenticated();
  }

  // Check if Spotify is connected
  Future<bool> isSpotifyConnected() async {
    return await _spotifyAuthService.isConnected();
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    return await _djangoAuthService.getUserProfile();
  }

  // Connect Spotify account
  Future<bool> connectSpotify() async {
    try {
      if (kDebugMode) {
        print("Initiating Spotify connection...");
      }
      
      // Using the SpotifyAuthService directly
      bool success = await _spotifyAuthService.authenticateWithSpotify();
      
      if (success && kDebugMode) {
        print("Successfully connected to Spotify");
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print("Error connecting to Spotify: $e");
      }
      return false;
    }
  }

  // Disconnect Spotify account
  Future<bool> disconnectSpotify() async {
    return await _spotifyAuthService.disconnect();
  }

  // Logout from the app (both Django and Spotify)
  Future<bool> logout() async {
    // DjangoAuthService.logout() now handles both Django and Spotify disconnection
    return await _djangoAuthService.logout();
  }

  // Get list of all connected music services
  Future<List<String>> getConnectedMusicServices() async {
    return await _djangoAuthService.getConnectedMusicServices();
  }

  // Test the Django backend connection
  Future<Map<String, dynamic>> testBackendConnection() async {
    if (kDebugMode) {
      print("Testing Django backend connection...");
    }
    
    try {
      Map<String, dynamic> result = await _djangoAuthService.testConnection();
      
      if (kDebugMode) {
        if (result['success']) {
          print("✅ Django connection test successful!");
          print("📊 Status: ${result['statusCode']}");
          print("⏱️ Response time: ${result['responseTime']} ms");
        } else {
          print("❌ Django connection test failed!");
          print("Error: ${result['error']}");
        }
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error testing Django connection: $e");
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
} 