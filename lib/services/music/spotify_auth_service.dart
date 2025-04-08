import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import '../../config/constants.dart';
import '../api/api_client.dart';

/// Service dedicated to handling Spotify authentication with the Django backend
class SpotifyAuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Storage keys for Spotify tokens
  static const String _accessTokenKey = 'spotify_backend_access_token';
  static const String _refreshTokenKey = 'spotify_backend_refresh_token';
  static const String _expiryTimeKey = 'spotify_backend_token_expiry';
  
  // Initiate Spotify authentication flow through Django backend
  Future<bool> authenticateWithSpotify() async {
    try {
      // Check if Django server is running
      try {
        final pingResponse = await http.get(
          Uri.parse('${AppConstants.baseApiUrl}/schema/'),
        );
        if (pingResponse.statusCode != 200) {
          throw Exception('Cannot connect to Django server at ${AppConstants.baseApiUrl}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Django server connection check failed: $e');
          print('Make sure your Django server is running at ${AppConstants.baseApiUrl}');
          print('Your server should be running at http://127.0.0.1:8000/');
        }
        throw Exception('Cannot connect to Django server. Is it running?');
      }
      
      // Get Spotify authorization URL from Django backend
      final response = await _apiClient.get(
        AppConstants.spotifyAuthEndpoint,
        requiresAuth: false,
      );
      
      if (!response.containsKey('auth_url')) {
        if (kDebugMode) {
          print('Failed to get Spotify auth URL from Django. Response: $response');
        }
        throw Exception('Failed to get Spotify auth URL from backend.');
      }
      
      final String authUrl = response['auth_url'];
      
      if (kDebugMode) {
        print('📱 Spotify Auth URL from Django: $authUrl');
      }
      
      // In development mode, simulate authentication flow
      if (kDebugMode) {
        try {
          final canLaunch = await canLaunchUrl(Uri.parse(authUrl));
          if (canLaunch) {
            // Launch Spotify auth page in browser
            await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
            print('🌐 Spotify auth URL launched in browser');
            print('🔄 After authentication, you should be redirected to: ${AppConstants.spotifyRedirectUri}');
            
            // Dev mode: Create persistent tokens for testing
            print('⚠️ Development mode: Creating persistent auth tokens for testing');
            
            // Check if we already have tokens to maintain consistency across hot reloads
            final existingToken = await _secureStorage.read(key: _accessTokenKey);
            if (existingToken == null) {
              final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
              await _secureStorage.write(key: _accessTokenKey, value: 'spotify_dev_token_$timestamp');
              await _secureStorage.write(key: _refreshTokenKey, value: 'spotify_dev_refresh_token_$timestamp');
              await _secureStorage.write(key: _expiryTimeKey, value: DateTime.now().add(const Duration(days: 7)).toIso8601String());
              print('✅ Created and stored new Spotify development tokens');
            } else {
              print('✅ Using existing cached Spotify auth tokens');
            }
            
            return true;
          } else {
            print('❌ Cannot launch URL: $authUrl');
            throw Exception('Cannot launch Spotify authentication URL');
          }
        } catch (e) {
          print('❌ Error launching Spotify auth URL: $e');
          throw Exception('Error during Spotify authentication: $e');
        }
      }
      
      // Production mode: Use flutter_web_auth for OAuth flow
      try {
        final result = await FlutterWebAuth.authenticate(
          url: authUrl,
          callbackUrlScheme: 'bopmaps', // Custom URL scheme for redirect
        );
        
        // Extract authorization code from callback URL
        final uri = Uri.parse(result);
        final code = uri.queryParameters['code'];
        
        if (code == null) {
          throw Exception('No authorization code received from Spotify');
        }
        
        if (kDebugMode) {
          print('✅ Spotify authorization code received: $code');
        }
        
        // Send code to Django backend callback handler
        final callbackResponse = await _apiClient.post(
          AppConstants.spotifyCallbackHandlerEndpoint,
          body: {
            'code': code,
            'redirect_uri': AppConstants.spotifyRedirectUri
          },
          requiresAuth: false,
        );
        
        // Validate response from Django
        if (!callbackResponse.containsKey('message') && !callbackResponse.containsKey('user')) {
          if (kDebugMode) {
            print('❌ Failed to exchange code for tokens. Response: $callbackResponse');
          }
          throw Exception('Failed to exchange Spotify code for tokens');
        }
        
        // Store tokens from Django response
        if (callbackResponse.containsKey('service')) {
          Map<String, dynamic> serviceData = callbackResponse['service'];
          await _storeTokens(
            serviceData['access_token'],
            serviceData['refresh_token'] ?? '',
            DateTime.parse(serviceData['expires_at']).difference(DateTime.now()).inSeconds,
          );
        } else if (callbackResponse.containsKey('access') && callbackResponse.containsKey('refresh')) {
          // JWT token format
          await _storeTokens(
            callbackResponse['access'],
            callbackResponse['refresh'],
            3600, // Default 1 hour expiry for JWT
          );
        } else {
          // Fallback token format
          await _storeTokens(
            callbackResponse['token'] ?? '',
            callbackResponse['refresh_token'] ?? '',
            callbackResponse['expires_in'] ?? 3600,
          );
        }
        
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error during Spotify web authentication flow: $e');
        }
        throw Exception('Spotify authentication failed: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error authenticating with Spotify: $e');
      }
      return false;
    }
  }
  
  // Store tokens securely
  Future<void> _storeTokens(String accessToken, String refreshToken, int expiresIn) async {
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
    
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _expiryTimeKey, value: expiryTime.toIso8601String());
    
    if (kDebugMode) {
      print('✅ Spotify tokens stored securely. Expires at: $expiryTime');
    }
  }
  
  // Check if user is connected to Spotify
  Future<bool> isConnected() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) return false;
      
      // If using dev token, just return true
      if (kDebugMode && accessToken.startsWith('spotify_dev_token_')) {
        print('⚠️ Development mode: Using cached Spotify token');
        return true;
      }
      
      // Check token expiry
      final expiryTimeString = await _secureStorage.read(key: _expiryTimeKey);
      if (expiryTimeString == null) return false;
      
      final expiryTime = DateTime.parse(expiryTimeString);
      if (DateTime.now().isAfter(expiryTime)) {
        // Token expired, would need to refresh
        // For now, just return false
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking Spotify connection: $e');
      }
      return false;
    }
  }
  
  // Disconnect from Spotify
  Future<bool> disconnect() async {
    try {
      // Clear stored tokens
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _expiryTimeKey);
      
      if (kDebugMode) {
        print('✅ Disconnected from Spotify (tokens cleared)');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disconnecting from Spotify: $e');
      }
      return false;
    }
  }
  
  // Get connected music services from Django
  Future<List<String>> getConnectedMusicServices() async {
    try {
      // In development mode with mock data
      if (kDebugMode) {
        final token = await _secureStorage.read(key: _accessTokenKey);
        if (token != null && token.startsWith('spotify_dev_token_')) {
          print('⚠️ Development mode: Returning mock Spotify connection status');
          return ['spotify'];
        } else {
          print('⚠️ Development mode: No Spotify connection');
          return [];
        }
      }
      
      // Would call API in production
      final response = await _apiClient.get(
        AppConstants.connectedServicesEndpoint,
        requiresAuth: false,
      );
      
      if (response.containsKey('services')) {
        return List<String>.from(response['services']);
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting connected music services: $e');
      }
      return [];
    }
  }
} 