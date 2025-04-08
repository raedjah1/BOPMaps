import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../models/music_track.dart';

class SpotifyService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String _clientId = AppConstants.spotifyClientId;
  final String _redirectUri = AppConstants.spotifyRedirectUri;
  
  // Spotify API endpoints
  static const String _authEndpoint = 'https://accounts.spotify.com/authorize';
  static const String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const String _apiBaseUrl = 'https://api.spotify.com/v1';
  
  // Storage keys
  static const String _accessTokenKey = 'spotify_access_token';
  static const String _refreshTokenKey = 'spotify_refresh_token';
  static const String _expiryTimeKey = 'spotify_token_expiry';
  
  // Check if user has connected Spotify
  Future<bool> isConnected() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) return false;
      
      // Check if token is expired
      final expiryTimeString = await _secureStorage.read(key: _expiryTimeKey);
      if (expiryTimeString == null) return false;
      
      final expiryTime = DateTime.parse(expiryTimeString);
      if (DateTime.now().isAfter(expiryTime)) {
        // Try to refresh the token
        return await _refreshToken();
      }
      
      return true;
    } catch (e) {
      print('Error checking Spotify connection: $e');
      return false;
    }
  }
  
  // Get authorization URL for OAuth flow
  String getAuthorizationUrl() {
    final scopes = [
      'user-read-private',
      'user-read-email',
      'user-library-read',
      'user-top-read',
      'streaming',
    ];
    
    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': scopes.join(' '),
      'show_dialog': 'true',
    };
    
    final uri = Uri.parse(_authEndpoint).replace(queryParameters: params);
    return uri.toString();
  }
  
  // Exchange authorization code for tokens
  Future<bool> exchangeCodeForTokens(String code) async {
    try {
      final body = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        // Note: In a production app, you should use a client_secret stored securely
        // This example is simplified for demonstration purposes
      };
      
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storeTokens(
          data['access_token'],
          data['refresh_token'],
          data['expires_in'],
        );
        return true;
      } else {
        throw Exception('Failed to exchange code for tokens: ${response.body}');
      }
    } catch (e) {
      print('Error exchanging code for tokens: $e');
      return false;
    }
  }
  
  // Store tokens securely
  Future<void> _storeTokens(String accessToken, String refreshToken, int expiresIn) async {
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
    
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _expiryTimeKey, value: expiryTime.toIso8601String());
  }
  
  // Refresh token when it expires
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;
      
      final body = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      };
      
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Some implementations don't always include refresh_token in response
        final newRefreshToken = data['refresh_token'] ?? refreshToken;
        
        await _storeTokens(
          data['access_token'],
          newRefreshToken,
          data['expires_in'],
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }
  
  // Get current access token (refreshing if needed)
  Future<String?> getAccessToken() async {
    try {
      if (!await isConnected()) return null;
      
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }
  
  // Make authenticated request to Spotify API
  Future<Map<String, dynamic>?> _makeAuthenticatedRequest(
    String endpoint,
    {String method = 'GET', Map<String, dynamic>? body}
  ) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return null;
      
      final uri = Uri.parse('$_apiBaseUrl$endpoint');
      late http.Response response;
      
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
      
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry the request
          return _makeAuthenticatedRequest(endpoint, method: method, body: body);
        } else {
          return null;
        }
      } else {
        print('API request failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error making authenticated request: $e');
      return null;
    }
  }
  
  // Search for tracks
  Future<List<MusicTrack>> searchTracks(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    
    final endpoint = '/search?q=${Uri.encodeComponent(query)}&type=track&limit=$limit';
    final response = await _makeAuthenticatedRequest(endpoint);
    
    if (response == null || !response.containsKey('tracks')) return [];
    
    final tracks = response['tracks']['items'] as List;
    return tracks.map((track) => _mapTrackResponse(track)).toList();
  }
  
  // Map Spotify track response to our MusicTrack model
  MusicTrack _mapTrackResponse(Map<String, dynamic> track) {
    String albumArt = '';
    if (track['album'] != null && 
        track['album']['images'] != null && 
        track['album']['images'].isNotEmpty) {
      albumArt = track['album']['images'][0]['url'];
    }
    
    String artistName = 'Unknown Artist';
    if (track['artists'] != null && track['artists'].isNotEmpty) {
      artistName = track['artists'][0]['name'];
    }
    
    List<String> genres = [];
    if (track['artists'] != null && 
        track['artists'].isNotEmpty && 
        track['artists'][0]['genres'] != null) {
      genres = List<String>.from(track['artists'][0]['genres']);
    }
    
    return MusicTrack(
      id: track['id'],
      title: track['name'],
      artist: artistName,
      album: track['album']['name'],
      albumArt: albumArt,
      url: track['external_urls']['spotify'] ?? '',
      service: 'spotify',
      previewUrl: track['preview_url'],
      serviceType: 'spotify',
      genres: genres,
      durationMs: track['duration_ms'] ?? 0,
      releaseDate: track['album'] != null && track['album']['release_date'] != null
          ? DateTime.parse(track['album']['release_date'])
          : null,
      explicit: track['explicit'] ?? false,
      popularity: track['popularity'] ?? 50,
    );
  }
  
  // Get user's recently played tracks
  Future<List<MusicTrack>> getRecentlyPlayed({int limit = 20}) async {
    final endpoint = '/me/player/recently-played?limit=$limit';
    final response = await _makeAuthenticatedRequest(endpoint);
    
    if (response == null || !response.containsKey('items')) return [];
    
    final items = response['items'] as List;
    return items.map((item) => _mapTrackResponse(item['track'])).toList();
  }
  
  // Disconnect from Spotify (clear tokens)
  Future<bool> disconnect() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _expiryTimeKey);
      return true;
    } catch (e) {
      print('Error disconnecting from Spotify: $e');
      return false;
    }
  }
} 