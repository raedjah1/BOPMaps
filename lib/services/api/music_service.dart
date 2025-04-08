import 'dart:convert';
import '../../config/constants.dart';
import '../../models/music_track.dart';
import 'api_client.dart';

class MusicService {
  final ApiClient _apiClient = ApiClient();
  
  // Search for tracks
  Future<List<MusicTrack>> searchTracks({
    required String query,
    required String serviceType,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.musicEndpoint}/search',
        queryParameters: {
          'query': query,
          'service': serviceType,
          'limit': limit.toString(),
        },
      );
      
      if (response['results'] == null) {
        return [];
      }
      
      final List<dynamic> results = response['results'];
      return results.map((trackData) => MusicTrack.fromJson(trackData)).toList();
    } catch (e) {
      print('Error searching tracks: $e');
      return [];
    }
  }
  
  // Get recently played tracks
  Future<List<MusicTrack>> getRecentlyPlayed({
    required String serviceType,
    int limit = 10,
  }) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.musicEndpoint}/recently-played',
        queryParameters: {
          'service': serviceType,
          'limit': limit.toString(),
        },
      );
      
      if (response['tracks'] == null) {
        return [];
      }
      
      final List<dynamic> tracks = response['tracks'];
      return tracks.map((trackData) => MusicTrack.fromJson(trackData)).toList();
    } catch (e) {
      print('Error getting recently played tracks: $e');
      
      // For demo purposes, return mock data
      return _getMockRecentTracks(serviceType);
    }
  }
  
  // Play a track
  Future<bool> playTrack({
    required String trackId,
    required String serviceType,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.musicEndpoint}/play',
        body: jsonEncode({
          'track_id': trackId,
          'service': serviceType,
        }),
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error playing track: $e');
      
      // For demo purposes, simulate successful playback
      return true;
    }
  }
  
  // Pause current track
  Future<bool> pauseTrack() async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.musicEndpoint}/pause',
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error pausing track: $e');
      
      // For demo purposes, simulate successful pause
      return true;
    }
  }
  
  // Get available music services for user
  Future<List<String>> getConnectedServices() async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.musicEndpoint}/connected-services',
      );
      
      if (response['services'] == null) {
        return [];
      }
      
      return List<String>.from(response['services']);
    } catch (e) {
      print('Error getting connected services: $e');
      
      // For demo purposes, return all services
      return ['spotify', 'apple_music', 'youtube_music'];
    }
  }
  
  // Connect a music service
  Future<bool> connectService(String serviceType) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.musicEndpoint}/connect',
        body: jsonEncode({
          'service': serviceType,
        }),
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error connecting service: $e');
      return false;
    }
  }
  
  // Disconnect a music service
  Future<bool> disconnectService(String serviceType) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.musicEndpoint}/disconnect',
        body: jsonEncode({
          'service': serviceType,
        }),
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error disconnecting service: $e');
      return false;
    }
  }
  
  // Get detailed track info
  Future<MusicTrack?> getTrackDetails({
    required String trackId,
    required String serviceType,
  }) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.musicEndpoint}/track/$trackId',
        queryParameters: {
          'service': serviceType,
        },
      );
      
      return MusicTrack.fromJson(response);
    } catch (e) {
      print('Error getting track details: $e');
      return null;
    }
  }
  
  // Get user playlists
  Future<List<Map<String, dynamic>>> getUserPlaylists({
    required String serviceType,
  }) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.musicEndpoint}/playlists',
        queryParameters: {
          'service': serviceType,
        },
      );
      
      if (response['playlists'] == null) {
        return [];
      }
      
      return List<Map<String, dynamic>>.from(response['playlists']);
    } catch (e) {
      print('Error getting user playlists: $e');
      return [];
    }
  }
  
  // Generate mock recent tracks for demo purposes
  List<MusicTrack> _getMockRecentTracks(String serviceType) {
    final mockTracks = [
      {
        'id': '1abc123',
        'title': 'Blinding Lights',
        'artist': 'The Weeknd',
        'album': 'After Hours',
        'albumArtUrl': 'https://example.com/album1.jpg',
        'durationMs': 200000,
        'serviceType': serviceType,
        'previewUrl': 'https://example.com/preview1.mp3',
      },
      {
        'id': '2abc123',
        'title': 'Watermelon Sugar',
        'artist': 'Harry Styles',
        'album': 'Fine Line',
        'albumArtUrl': 'https://example.com/album2.jpg',
        'durationMs': 174000,
        'serviceType': serviceType,
        'previewUrl': 'https://example.com/preview2.mp3',
      },
      {
        'id': '3abc123',
        'title': 'Don\'t Start Now',
        'artist': 'Dua Lipa',
        'album': 'Future Nostalgia',
        'albumArtUrl': 'https://example.com/album3.jpg',
        'durationMs': 183000,
        'serviceType': serviceType,
        'previewUrl': 'https://example.com/preview3.mp3',
      },
      {
        'id': '4abc123',
        'title': 'bad guy',
        'artist': 'Billie Eilish',
        'album': 'WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?',
        'albumArtUrl': 'https://example.com/album4.jpg',
        'durationMs': 194000,
        'serviceType': serviceType,
        'previewUrl': 'https://example.com/preview4.mp3',
      },
      {
        'id': '5abc123',
        'title': 'Savage Love',
        'artist': 'Jason Derulo',
        'album': 'Savage Love',
        'albumArtUrl': 'https://example.com/album5.jpg',
        'durationMs': 171000,
        'serviceType': serviceType,
        'previewUrl': 'https://example.com/preview5.mp3',
      },
    ];
    
    return mockTracks.map((data) => MusicTrack.fromJson(data)).toList();
  }
} 