import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../music/spotify_auth_service.dart';
import 'api_client.dart';

class DjangoAuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SpotifyAuthService _spotifyAuthService = SpotifyAuthService();
  
  // Storage keys for tokens
  static const String _accessTokenKey = 'django_access_token';
  static const String _refreshTokenKey = 'django_refresh_token';
  static const String _tokenExpiryKey = 'django_token_expiry';
  
  // Endpoints based on Django API structure
  static const String _usersAuthBase = '/users/auth';
  static const String _tokenEndpoint = '$_usersAuthBase/token/';
  static const String _tokenRefreshEndpoint = '$_usersAuthBase/token/refresh/';
  static const String _userProfileEndpoint = '/users/me/';
  
  // New method to test Django backend connection
  Future<Map<String, dynamic>> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔄 Testing Django backend connection...');
        print('📍 Checking API endpoint: ${AppConstants.baseApiUrl}/schema/');
      }
      
      // Measure response time
      final stopwatch = Stopwatch()..start();
      
      try {
        final response = await http.get(
          Uri.parse('${AppConstants.baseApiUrl}/schema/'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        
        stopwatch.stop();
        
        final statusCode = response.statusCode;
        final responseTime = stopwatch.elapsedMilliseconds;
        
        if (kDebugMode) {
          print('✅ Connection successful!');
          print('📊 Status code: $statusCode');
          print('⏱️ Response time: $responseTime ms');
          
          if (response.body.isNotEmpty && response.body.length < 1000) {
            print('📦 Response: ${response.body}');
          } else {
            print('📦 Response received (${response.body.length} bytes)');
          }
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'responseTime': responseTime,
          'baseUrl': AppConstants.baseApiUrl,
        };
      } catch (e) {
        stopwatch.stop();
        
        if (kDebugMode) {
          print('❌ Connection failed!');
          print('❌ Error: $e');
        }
        
        return {
          'success': false,
          'error': e.toString(),
          'baseUrl': AppConstants.baseApiUrl,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error testing connection: $e');
      }
      
      return {
        'success': false,
        'error': 'Internal error: $e',
      };
    }
  }
  
  // Initiate Spotify authentication flow - delegated to SpotifyAuthService
  Future<bool> authenticateWithSpotify() async {
    // For backward compatibility, simply delegate to the new service
    return await _spotifyAuthService.authenticateWithSpotify();
  }
  
  // Store tokens securely
  Future<void> _storeTokens(String accessToken, String refreshToken, int expiresIn) async {
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
    
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _tokenExpiryKey, value: expiryTime.toIso8601String());
    
    if (kDebugMode) {
      print('Tokens stored successfully. Expires at: $expiryTime');
    }
  }
  
  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) return false;
      
      // Check if token is expired
      final expiryTimeString = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryTimeString == null) return false;
      
      final expiryTime = DateTime.parse(expiryTimeString);
      if (DateTime.now().isAfter(expiryTime)) {
        // Try to refresh the token
        return await _refreshToken();
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking authentication: $e');
      }
      return false;
    }
  }
  
  // Refresh authentication token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;
      
      // Use the specific refresh token endpoint from your Django API
      final response = await _apiClient.post(
        _tokenRefreshEndpoint,
        body: {'refresh': refreshToken},
        requiresAuth: false,
      );
      
      if (!response.containsKey('access')) {
        return false;
      }
      
      // Calculate a new expiry time (typically 1 hour for JWT)
      final expiryTime = DateTime.now().add(const Duration(hours: 1));
      
      // Store the new access token and update expiry time
      await _secureStorage.write(key: _accessTokenKey, value: response['access']);
      await _secureStorage.write(key: _tokenExpiryKey, value: expiryTime.toIso8601String());
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing token: $e');
      }
      return false;
    }
  }
  
  // Get current user profile from Django backend
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      // In debug mode with localhost backend, simply return mock data
      if (kDebugMode && (AppConstants.baseApiUrl.contains('localhost') || AppConstants.baseApiUrl.contains('127.0.0.1'))) {
        print('⚠️ Development mode: Returning consistent mock user profile');
        
        // Check if Spotify is connected
        bool spotifyConnected = await _spotifyAuthService.isConnected();
        
        // Return a mock profile with stable values
        return {
          'id': 123,
          'username': 'test_user',
          'email': 'user@example.com',
          'profile': {
            'bio': 'BOPMaps user (Dev Mode)',
            'avatar': null,
            'location': null,
          },
          'spotify_connected': spotifyConnected,
        };
      }
      
      if (!await isAuthenticated()) return null;
      
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      
      // Try to fetch the user profile from your Django API
      try {
        final response = await http.get(
          Uri.parse('${AppConstants.baseApiUrl}$_userProfileEndpoint'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (kDebugMode) {
            print('User profile retrieved successfully.');
          }
          return data;
        } else if (response.statusCode == 401) {
          // Token might be expired, try to refresh it
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request with the new token
            return await getUserProfile();
          }
        }
        
        if (kDebugMode) {
          print('Failed to get user profile. Status code: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        
        return null;
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user profile: $e');
        }
        
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user profile: $e');
      }
      return null;
    }
  }
  
  // Get connected music services - delegated to SpotifyAuthService
  Future<List<String>> getConnectedMusicServices() async {
    return await _spotifyAuthService.getConnectedMusicServices();
  }
  
  // Logout (clear tokens and notify Django backend)
  Future<bool> logout() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      
      // Notify backend about logout if we have a token
      if (accessToken != null) {
        try {
          await http.post(
            Uri.parse('${AppConstants.baseApiUrl}$_usersAuthBase/logout/'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error notifying backend about logout: $e');
          }
          // Continue with local logout even if backend request fails
        }
      }
      
      // Clear stored tokens
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      
      // Also disconnect from Spotify
      await _spotifyAuthService.disconnect();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      // Always return true for logout, even if some steps fail
      return true;
    }
  }
} 