import 'dart:convert';
import '../models/api_response.dart';
import '../models/pin.dart';
import 'api_service.dart';

class PinsService {
  final ApiService _apiService;
  
  PinsService(this._apiService);
  
  // Get nearby pins with pagination
  Future<List<Pin>> getNearbyPins(
    double latitude,
    double longitude,
    double radius, {
    int page = 1,
    int limit = 50,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/api/geo/nearby/',
      queryParams: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      },
      token: token,
    );
    
    if (!response.success) {
      throw Exception(response.userFriendlyMessage);
    }
    
    final results = response.data['results'] as List<dynamic>;
    return results.map((json) => Pin.fromJson(json)).toList();
  }
  
  // Create a new pin
  Future<Pin> createPin({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String trackTitle,
    required String trackArtist,
    required String trackUrl,
    required String service,
    String? album,
    bool isPrivate = false,
    String? token,
  }) async {
    final response = await _apiService.post(
      '/api/pins/',
      data: {
        'title': title,
        'description': description,
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'track_title': trackTitle,
        'track_artist': trackArtist,
        'track_url': trackUrl,
        'service': service,
        'album': album,
        'is_private': isPrivate,
      },
      token: token,
    );
    
    if (!response.success) {
      throw Exception(response.userFriendlyMessage);
    }
    
    return Pin.fromJson(response.data);
  }
  
  // Get a specific pin by ID
  Future<Pin> getPinById(String pinId, {String? token}) async {
    final response = await _apiService.get(
      '/api/pins/$pinId/',
      token: token,
    );
    
    if (!response.success) {
      throw Exception(response.userFriendlyMessage);
    }
    
    return Pin.fromJson(response.data);
  }
  
  // Interact with a pin (view, collect, like)
  Future<ApiResponse> interactWithPin(
    String pinId,
    String interactionType, {
    String? token,
  }) async {
    final response = await _apiService.post(
      '/api/pins/$pinId/interact/',
      data: {
        'interaction_type': interactionType,
      },
      token: token,
    );
    
    return response;
  }
  
  // Update a pin
  Future<Pin> updatePin(
    String pinId, {
    String? title,
    String? description,
    bool? isPrivate,
    String? token,
  }) async {
    final Map<String, dynamic> data = {};
    
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (isPrivate != null) data['is_private'] = isPrivate;
    
    final response = await _apiService.patch(
      '/api/pins/$pinId/',
      data: data,
      token: token,
    );
    
    if (!response.success) {
      throw Exception(response.userFriendlyMessage);
    }
    
    return Pin.fromJson(response.data);
  }
  
  // Delete a pin
  Future<bool> deletePin(String pinId, {String? token}) async {
    final response = await _apiService.delete(
      '/api/pins/$pinId/',
      token: token,
    );
    
    return response.success;
  }
} 