import 'api_client.dart';
import '../../config/constants.dart';
import '../../models/pin.dart';
import '../../models/user.dart';
import '../../models/music_track.dart';

class PinsService {
  final ApiClient _apiClient = ApiClient();
  
  // Get nearby pins
  Future<List<Pin>> getNearbyPins(
    double latitude,
    double longitude,
    double radius,
  ) async {
    try {
      final response = await _apiClient.get(
        AppConstants.pinsEndpoint,
        queryParams: {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius': radius.toString(),
        },
        requiresAuth: true,
      );
      
      if (response.containsKey('results')) {
        final results = response['results'] as List;
        return results.map((pinJson) => Pin.fromJson(pinJson)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting nearby pins: $e');
      return [];
    }
  }
  
  // Get pin details
  Future<Pin?> getPinDetails(int pinId) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.pinsEndpoint}/$pinId',
        requiresAuth: true,
      );
      
      return Pin.fromJson(response);
    } catch (e) {
      print('Error getting pin details: $e');
      return null;
    }
  }
  
  // Create a new pin
  Future<Pin?> createPin({
    required String title,
    String? description,
    required int trackId,
    required String serviceType,
    required String skinId,
    required double latitude,
    required double longitude,
    bool isPrivate = false,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConstants.pinsEndpoint,
        body: {
          'title': title,
          'description': description,
          'track_id': trackId,
          'service_type': serviceType,
          'skin_id': skinId,
          'latitude': latitude,
          'longitude': longitude,
          'is_private': isPrivate,
        },
        requiresAuth: true,
      );
      
      return Pin.fromJson(response);
    } catch (e) {
      print('Error creating pin: $e');
      return null;
    }
  }
  
  // Update a pin
  Future<Pin?> updatePin({
    required int pinId,
    String? title,
    String? description,
    String? skinId,
    bool? isPrivate,
  }) async {
    try {
      // Create request body with non-null fields
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (skinId != null) body['skin_id'] = skinId;
      if (isPrivate != null) body['is_private'] = isPrivate;
      
      final response = await _apiClient.patch(
        '${AppConstants.pinsEndpoint}/$pinId',
        body: body,
        requiresAuth: true,
      );
      
      return Pin.fromJson(response);
    } catch (e) {
      print('Error updating pin: $e');
      return null;
    }
  }
  
  // Delete a pin
  Future<bool> deletePin(int pinId) async {
    try {
      final response = await _apiClient.delete(
        '${AppConstants.pinsEndpoint}/$pinId',
        requiresAuth: true,
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error deleting pin: $e');
      return false;
    }
  }
  
  // Collect a pin
  Future<bool> collectPin(int pinId) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.pinsEndpoint}/$pinId/collect',
        requiresAuth: true,
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error collecting pin: $e');
      return false;
    }
  }
  
  // Get pins by user
  Future<List<Pin>> getPinsByUser(int userId) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.usersEndpoint}/$userId/pins',
        requiresAuth: true,
      );
      
      if (response.containsKey('results')) {
        final results = response['results'] as List;
        return results.map((pinJson) => Pin.fromJson(pinJson)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting pins by user: $e');
      return [];
    }
  }
  
  // Get collected pins
  Future<List<Pin>> getCollectedPins() async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.pinsEndpoint}/collected',
        requiresAuth: true,
      );
      
      if (response.containsKey('results')) {
        final results = response['results'] as List;
        return results.map((pinJson) => Pin.fromJson(pinJson)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting collected pins: $e');
      return [];
    }
  }
  
  // Get popular pins
  Future<List<Pin>> getPopularPins() async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.pinsEndpoint}/popular',
        requiresAuth: true,
      );
      
      if (response.containsKey('results')) {
        final results = response['results'] as List;
        return results.map((pinJson) => Pin.fromJson(pinJson)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting popular pins: $e');
      return [];
    }
  }
  
  // Like a pin
  Future<bool> likePin(int pinId) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.pinsEndpoint}/$pinId/like',
        requiresAuth: true,
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error liking pin: $e');
      return false;
    }
  }
  
  // Unlike a pin
  Future<bool> unlikePin(int pinId) async {
    try {
      final response = await _apiClient.delete(
        '${AppConstants.pinsEndpoint}/$pinId/like',
        requiresAuth: true,
      );
      
      return response['success'] == true;
    } catch (e) {
      print('Error unliking pin: $e');
      return false;
    }
  }
  
  // Generate sample pin for testing
  Pin generateSamplePin({
    required int id,
    required double latitude,
    required double longitude,
    required String title,
  }) {
    // Create a sample user
    final user = User(
      id: 1,
      username: 'sampleuser',
      email: 'sample@example.com',
      isVerified: true,
      favoriteGenres: ['pop', 'rock'],
      connectedServices: {
        'spotify': true,
        'apple_music': false,
        'soundcloud': false,
      },
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    
    // Create a sample track
    final track = MusicTrack.sampleTrack();
    
    // Create and return a sample pin
    return Pin(
      id: id,
      owner: user,
      latitude: latitude,
      longitude: longitude,
      title: title,
      description: 'This is a sample pin for testing purposes.',
      track: track,
      serviceType: 'spotify',
      skinId: 'default',
      rarity: PinRarity.common,
      auraRadius: 50.0,
      isPrivate: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }
} 