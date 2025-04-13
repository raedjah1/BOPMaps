import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A class to fetch and process OpenStreetMap data for 2.5D rendering
class OSMDataProcessor {
  // Cache for processed data to avoid redundant API calls
  final Map<String, dynamic> _dataCache = {};
  
  // Timeout duration for API requests
  final Duration _timeout = const Duration(seconds: 15);
  
  // API throttling control - improve to avoid quota issues
  DateTime _lastRequestTime = DateTime.now().subtract(const Duration(seconds: 30));
  Duration _minimumTimeBetweenRequests = const Duration(seconds: 10); // Increased from 5s to 10s
  int _consecutiveErrors = 0;
  static const _maxConsecutiveErrors = 3;
  
  // Exponential backoff for rate limiting
  Duration _currentBackoff = const Duration(seconds: 15);
  static const _maxBackoff = Duration(seconds: 60);
  
  // List of alternate Overpass API endpoints to try
  final List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  int _currentEndpointIndex = 0;

  // Track endpoint performance
  final Map<String, int> _endpointErrorCounts = {};
  
  // Check if we need to throttle our requests
  Future<void> _throttleRequests() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    
    // If we've had errors recently, apply exponential backoff
    final effectiveDelay = _consecutiveErrors > 0 
        ? _currentBackoff 
        : _minimumTimeBetweenRequests;
    
    if (timeSinceLastRequest < effectiveDelay) {
      // Wait until we can make another request
      final waitTime = effectiveDelay - timeSinceLastRequest;
      debugPrint('Throttling Overpass API request, waiting for ${waitTime.inMilliseconds}ms');
      await Future.delayed(waitTime);
    }
  }
  
  // Handle API errors with better backoff strategy
  void _handleApiError(String errorMessage) {
    debugPrint('API Error: $errorMessage');
    _incrementErrorCounter();
    
    // Implement exponential backoff
    _currentBackoff = Duration(seconds: math.min(
      _currentBackoff.inSeconds * 2, 
      _maxBackoff.inSeconds
    ));
    
    debugPrint('Backoff increased to ${_currentBackoff.inSeconds} seconds');
  }
  
  // Reset backoff on successful request
  void _handleSuccessfulRequest() {
    _consecutiveErrors = 0;
    _currentBackoff = const Duration(seconds: 15);
  }
  
  /// Fetches building data from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchBuildingData(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for Overpass API query');
      return [];
    }
    
    final String cacheKey = 'buildings_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached building data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    await _throttleRequests();
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors * 2) {
      // If way too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      
      // Schedule a reset of the error counter after some time
      Future.delayed(const Duration(minutes: 5), () {
        _consecutiveErrors = math.max(0, _consecutiveErrors - 2);
      });
      
      return [];
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.04 degrees (approximately 4km) - reduced from previous 0.05
    if (latDelta > 0.04 || lonDelta > 0.04) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.02,
        center.longitude - 0.02
      );
      
      newNE = LatLng(
        center.latitude + 0.02,
        center.longitude + 0.02
      );
      
      debugPrint('Area too large, reducing building query size to center region');
    }
    
    // Construct Overpass API query for buildings with proper syntax
    final String query = '''
      [out:json][timeout:25];
      (
        way["building"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching building data from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
      final response = await http.post(
        Uri.parse(endpoint),
        body: query,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'BOPMaps/1.0 (Flutter App; contact@bopmaps.com)'
        }
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Reset consecutive error counter on success
        _handleSuccessfulRequest();
        
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        debugPrint('Received ${elements.length} building elements');
        
        // Process building elements
        final List<Map<String, dynamic>> buildings = elements
            .where((element) => element['type'] == 'way' && element['tags'].containsKey('building'))
            .map<Map<String, dynamic>>((building) {
              // Extract building height or estimate based on building:levels
              double height = 10.0; // Default height in meters
              
              if (building['tags'].containsKey('height')) {
                height = double.tryParse(building['tags']['height'].toString()) ?? height;
              } else if (building['tags'].containsKey('building:levels')) {
                // Estimate: ~3 meters per level
                final levels = double.tryParse(building['tags']['building:levels'].toString()) ?? 1.0;
                height = levels * 3.0;
              }
              
              // Process geometry
              final List<LatLng> points = [];
              if (building.containsKey('geometry')) {
                for (final node in building['geometry']) {
                  points.add(LatLng(node['lat'], node['lon']));
                }
              }
              
              return {
                'id': building['id'],
                'height': height,
                'points': points,
                'tags': building['tags'],
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = buildings;
        return buildings;
      } else {
        debugPrint('Failed to fetch buildings: ${response.statusCode} - ${response.body}');
        _handleApiError('Failed to fetch buildings');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching building data: $e');
      _handleApiError('Error fetching building data');
      return [];
    }
  }

  /// Fetches road network data from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchRoadData(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for Overpass API query');
      return [];
    }
    
    final String cacheKey = 'roads_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached road data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    await _throttleRequests();
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors * 2) {
      // If way too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      
      // Schedule a reset of the error counter after some time
      Future.delayed(const Duration(minutes: 5), () {
        _consecutiveErrors = math.max(0, _consecutiveErrors - 2);
      });
      
      return [];
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.04 degrees (approximately 4km) - reduced from previous 0.05
    if (latDelta > 0.04 || lonDelta > 0.04) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.02,
        center.longitude - 0.02
      );
      
      newNE = LatLng(
        center.latitude + 0.02,
        center.longitude + 0.02
      );
      
      debugPrint('Area too large, reducing road query size to center region');
    }
    
    // Construct Overpass API query for roads with proper syntax
    final String query = '''
      [out:json][timeout:25];
      (
        way["highway"~"motorway|trunk|primary|secondary|tertiary|residential"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching road data from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
      final response = await http.post(
        Uri.parse(endpoint),
        body: query,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'BOPMaps/1.0 (Flutter App; contact@bopmaps.com)'
        }
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Reset consecutive error counter on success
        _handleSuccessfulRequest();
        
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        debugPrint('Received ${elements.length} road elements');
        
        // Process road elements
        final List<Map<String, dynamic>> roads = elements
            .where((element) => element['type'] == 'way' && element['tags'].containsKey('highway'))
            .map<Map<String, dynamic>>((road) {
              // Determine road width and elevation based on road type
              double width = 1.0;
              double elevation = 0.5;
              
              final String highwayType = road['tags']['highway'];
              
              // Adjust width and elevation based on road importance
              switch (highwayType) {
                case 'motorway':
                  width = 5.0;
                  elevation = 1.5;
                  break;
                case 'trunk':
                  width = 4.5;
                  elevation = 1.4;
                  break;
                case 'primary':
                  width = 4.0;
                  elevation = 1.3;
                  break;
                case 'secondary':
                  width = 3.5;
                  elevation = 1.2;
                  break;
                case 'tertiary':
                  width = 3.0;
                  elevation = 1.0;
                  break;
                case 'residential':
                  width = 2.5;
                  elevation = 0.8;
                  break;
                default:
                  width = 2.0;
                  elevation = 0.5;
              }
              
              // Process geometry
              final List<LatLng> points = [];
              if (road.containsKey('geometry')) {
                for (final node in road['geometry']) {
                  points.add(LatLng(node['lat'], node['lon']));
                }
              }
              
              return {
                'id': road['id'],
                'width': width,
                'elevation': elevation,
                'points': points,
                'tags': road['tags'],
                'type': highwayType,
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = roads;
        return roads;
      } else {
        debugPrint('Failed to fetch roads: ${response.statusCode} - ${response.body}');
        _handleApiError('Failed to fetch roads');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching road data: $e');
      _handleApiError('Error fetching road data');
      return [];
    }
  }

  /// Fetches points of interest from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchPointsOfInterest(LatLng southwest, LatLng northeast) async {
    final String cacheKey = 'pois_${southwest.latitude}_${southwest.longitude}_${northeast.latitude}_${northeast.longitude}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      return _dataCache[cacheKey];
    }
    
    // Construct Overpass API query for POIs with fixed syntax
    final String query = '''
      [out:json][timeout:25];
      (
        node["amenity"](${southwest.latitude},${southwest.longitude},${northeast.latitude},${northeast.longitude});
        node["shop"](${southwest.latitude},${southwest.longitude},${northeast.latitude},${northeast.longitude});
        node["tourism"](${southwest.latitude},${southwest.longitude},${northeast.latitude},${northeast.longitude});
      );
      out body;
    ''';
    
    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        // Process POI elements
        final List<Map<String, dynamic>> pois = elements
            .map<Map<String, dynamic>>((poi) {
              String category = 'other';
              String subCategory = 'unknown';
              
              if (poi['tags'].containsKey('amenity')) {
                category = 'amenity';
                subCategory = poi['tags']['amenity'];
              } else if (poi['tags'].containsKey('shop')) {
                category = 'shop';
                subCategory = poi['tags']['shop'];
              } else if (poi['tags'].containsKey('tourism')) {
                category = 'tourism';
                subCategory = poi['tags']['tourism'];
              }
              
              return {
                'id': poi['id'],
                'lat': poi['lat'],
                'lon': poi['lon'],
                'category': category,
                'subCategory': subCategory,
                'name': poi['tags']['name'] ?? 'Unknown',
                'tags': poi['tags'],
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = pois;
        return pois;
      } else {
        print('Failed to fetch POIs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching POI data: $e');
      return [];
    }
  }

  /// Fetches Points of Interest (POIs) from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchPOIData(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for Overpass API query');
      return [];
    }
    
    final String cacheKey = 'pois_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached POI data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    await _throttleRequests();
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors * 2) {
      // If way too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      
      // Schedule a reset of the error counter after some time
      Future.delayed(const Duration(minutes: 5), () {
        _consecutiveErrors = math.max(0, _consecutiveErrors - 2);
      });
      
      return [];
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.04 degrees (approximately 4km) - reduced from previous 0.05
    if (latDelta > 0.04 || lonDelta > 0.04) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.02,
        center.longitude - 0.02
      );
      
      newNE = LatLng(
        center.latitude + 0.02,
        center.longitude + 0.02
      );
      
      debugPrint('Area too large, reducing POI query size to center region');
    }
    
    // Construct Overpass API query for POIs
    // We need to query various tags to get POIs of different categories
    final String query = '''
      [out:json][timeout:25];
      (
        // Food & Drink
        node["amenity"~"restaurant|cafe|bar|fast_food"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Accommodation
        node["tourism"="hotel"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Entertainment & Arts
        node["amenity"~"theatre|cinema|arts_centre|nightclub"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        node["tourism"~"museum|gallery|attraction"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Education
        node["amenity"~"library|university|school"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Shopping
        node["shop"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        node["amenity"="marketplace"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Transport & Services
        node["amenity"~"fuel|parking|bank|hospital"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Recreation & Leisure
        node["leisure"~"park|garden"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        node["tourism"="viewpoint"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Landmarks
        node["historic"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        node["tourism"="information"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching POI data from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
      final response = await http.post(
        Uri.parse(endpoint),
        body: query,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'BOPMaps/1.0 (Flutter App; contact@bopmaps.com)'
        }
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Reset consecutive error counter on success
        _handleSuccessfulRequest();
        
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        debugPrint('Received ${elements.length} POI elements');
        
        // Process POI elements
        final List<Map<String, dynamic>> pois = elements
            .where((element) => element['type'] == 'node')
            .map<Map<String, dynamic>>((poi) {
              // Determine POI category
              final Map<String, dynamic> tags = poi['tags'] as Map<String, dynamic>;
              final String category = _determinePOICategory(tags);
              final double importance = _calculatePOIImportance(tags, category);
              
              return {
                'id': poi['id'],
                'location': LatLng(poi['lat'], poi['lon']),
                'category': category,
                'name': tags['name'] ?? '',
                'tags': tags,
                'importance': importance,
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = pois;
        return pois;
      } else {
        debugPrint('Failed to fetch POIs: ${response.statusCode} - ${response.body}');
        _handleApiError('Failed to fetch POIs');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching POI data: $e');
      _handleApiError('Error fetching POI data');
      return [];
    }
  }
  
  /// Determines the category of a POI based on its OSM tags
  String _determinePOICategory(Map<String, dynamic> tags) {
    // Check amenity tag first (most common)
    if (tags.containsKey('amenity')) {
      final String amenity = tags['amenity'] as String;
      
      // Food & Drink
      if (amenity == 'restaurant') return 'restaurant';
      if (amenity == 'cafe') return 'cafe';
      if (amenity == 'bar') return 'bar';
      if (amenity == 'fast_food') return 'fast_food';
      
      // Entertainment
      if (amenity == 'theatre') return 'theatre';
      if (amenity == 'cinema') return 'cinema';
      if (amenity == 'arts_centre') return 'arts_centre';
      if (amenity == 'nightclub') return 'nightclub';
      
      // Education
      if (amenity == 'library') return 'library';
      if (amenity == 'university') return 'university';
      if (amenity == 'school') return 'university'; // Simplify to same icon
      
      // Services
      if (amenity == 'fuel') return 'fuel';
      if (amenity == 'parking') return 'parking';
      if (amenity == 'bank') return 'bank';
      if (amenity == 'hospital') return 'hospital';
      if (amenity == 'marketplace') return 'marketplace';
      
      // Default amenity
      return 'entertainment';
    }
    
    // Check shop tag
    if (tags.containsKey('shop')) {
      final String shop = tags['shop'] as String;
      
      // Special cases for specific shops
      if (shop == 'supermarket') return 'supermarket';
      
      // All other shops
      return 'shop';
    }
    
    // Check tourism tag
    if (tags.containsKey('tourism')) {
      final String tourism = tags['tourism'] as String;
      
      if (tourism == 'hotel') return 'hotel';
      if (tourism == 'museum') return 'museum';
      if (tourism == 'gallery') return 'gallery';
      if (tourism == 'attraction') return 'attraction';
      if (tourism == 'viewpoint') return 'viewpoint';
      if (tourism == 'information') return 'landmark';
      
      // Default tourism
      return 'attraction';
    }
    
    // Check historic tag
    if (tags.containsKey('historic')) {
      return 'landmark';
    }
    
    // Check leisure tag
    if (tags.containsKey('leisure')) {
      final String leisure = tags['leisure'] as String;
      
      if (leisure == 'park' || leisure == 'garden') return 'park';
      
      return 'entertainment';
    }
    
    // Fallback
    return 'unknown';
  }
  
  /// Calculates an importance score for a POI based on various factors
  double _calculatePOIImportance(Map<String, dynamic> tags, String category) {
    double score = 0.5; // Default medium importance
    
    // Named POIs are more important
    if (tags.containsKey('name')) {
      score += 0.1;
    }
    
    // Certain types of POIs are more prominent
    if (category == 'landmark' || category == 'museum' || 
        category == 'theatre' || category == 'attraction') {
      score += 0.2;
    } else if (category == 'restaurant' || category == 'hotel' || 
              category == 'supermarket' || category == 'hospital') {
      score += 0.15;
    }
    
    // Some specific features affect importance
    if (tags.containsKey('website')) score += 0.05;
    if (tags.containsKey('phone')) score += 0.05;
    if (tags.containsKey('wikipedia')) score += 0.1;
    if (tags.containsKey('stars')) {
      // More stars = more importance
      final starsStr = tags['stars'] as String;
      final stars = double.tryParse(starsStr) ?? 0.0;
      score += stars / 25.0; // Max 0.2 for 5 stars
    }
    
    // Normalize to 0.0-1.0 range
    return score.clamp(0.0, 1.0);
  }
  
  /// Fetches water features from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchWaterFeaturesData(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for Overpass API query');
      return [];
    }
    
    final String cacheKey = 'water_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached water data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    await _throttleRequests();
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors * 2) {
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      return [];
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.04 degrees (approximately 4km) - consistent with other queries
    if (latDelta > 0.04 || lonDelta > 0.04) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.02,
        center.longitude - 0.02
      );
      
      newNE = LatLng(
        center.latitude + 0.02,
        center.longitude + 0.02
      );
      
      debugPrint('Area too large, reducing water features query size to center region');
    }
    
    // Construct Overpass API query for water features with proper syntax
    final String query = '''
      [out:json][timeout:25];
      (
        // Natural water features
        way["natural"="water"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        relation["natural"="water"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Waterways
        way["waterway"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Coastlines
        way["natural"="coastline"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching water features data from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
      final response = await http.post(
        Uri.parse(endpoint),
        body: query,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'BOPMaps/1.0 (Flutter App; contact@bopmaps.com)'
        }
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Reset consecutive error counter on success
        _handleSuccessfulRequest();
        
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        debugPrint('Received ${elements.length} water feature elements');
        
        // Process water elements
        final List<Map<String, dynamic>> waterFeatures = elements
            .where((element) => element['type'] == 'way' && 
                (element['tags'].containsKey('natural') || element['tags'].containsKey('waterway')))
            .map<Map<String, dynamic>>((feature) {
              // Determine water feature type
              String waterType = 'unknown';
              
              if (feature['tags'].containsKey('waterway')) {
                waterType = feature['tags']['waterway'];
              } else if (feature['tags'].containsKey('natural')) {
                if (feature['tags']['natural'] == 'water') {
                  // Check for water type
                  if (feature['tags'].containsKey('water')) {
                    waterType = feature['tags']['water'];
                  } else {
                    waterType = 'water';
                  }
                } else if (feature['tags']['natural'] == 'coastline') {
                  waterType = 'coastline';
                }
              }
              
              // Process geometry
              final List<LatLng> points = [];
              if (feature.containsKey('geometry')) {
                for (final node in feature['geometry']) {
                  points.add(LatLng(node['lat'], node['lon']));
                }
              }
              
              return {
                'id': feature['id'],
                'type': waterType,
                'points': points,
                'tags': feature['tags'],
                'elevation': 0.0, // Water will be at base level
                'width': _getWaterwayWidth(waterType),
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = waterFeatures;
        return waterFeatures;
      } else {
        debugPrint('Failed to fetch water features: ${response.statusCode} - ${response.body}');
        _handleApiError('Failed to fetch water features');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching water feature data: $e');
      _handleApiError('Error fetching water feature data');
      return [];
    }
  }
  
  /// Determine waterway width based on type
  double _getWaterwayWidth(String waterType) {
    switch (waterType) {
      case 'river': return 8.0;
      case 'stream': return 3.0;
      case 'canal': return 6.0;
      case 'drain': return 2.0;
      case 'ditch': return 1.5;
      default: return 4.0; // Default width for other water types
    }
  }

  /// Fetches parks and green spaces from the Overpass API for a given bounding box
  Future<Map<String, List<Map<String, dynamic>>>> fetchParksData(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for Overpass API query');
      return {};
    }
    
    final String cacheKey = 'parks_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached parks data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    await _throttleRequests();
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors * 2) {
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      return {};
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.04 degrees (approximately 4km) - consistent with other queries
    if (latDelta > 0.04 || lonDelta > 0.04) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.02,
        center.longitude - 0.02
      );
      
      newNE = LatLng(
        center.latitude + 0.02,
        center.longitude + 0.02
      );
      
      debugPrint('Area too large, reducing parks query size to center region');
    }
    
    // Construct Overpass API query for parks and green spaces
    final String query = '''
      [out:json][timeout:25];
      (
        // Parks and green spaces
        way["leisure"="park"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        relation["leisure"="park"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["landuse"="forest"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["landuse"="grass"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["landuse"="meadow"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["natural"="wood"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Individual trees
        node["natural"="tree"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching parks data from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
      final response = await http.post(
        Uri.parse(endpoint),
        body: query,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'BOPMaps/1.0 (Flutter App; contact@bopmaps.com)'
        }
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Reset consecutive error counter on success
        _handleSuccessfulRequest();
        
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        debugPrint('Received ${elements.length} park/vegetation elements');
        
        // Process parks and trees
        final List<Map<String, dynamic>> parks = [];
        final List<Map<String, dynamic>> trees = [];
        
        for (final element in elements) {
          if (element['type'] == 'node' && element['tags'].containsKey('natural') && 
              element['tags']['natural'] == 'tree') {
            // Process individual trees
            trees.add({
              'id': element['id'],
              'location': LatLng(element['lat'], element['lon']),
              'tags': element['tags'],
            });
          } else if (element['type'] == 'way') {
            // Process area features like parks and forests
            final List<LatLng> points = [];
            if (element.containsKey('geometry')) {
              for (final node in element['geometry']) {
                points.add(LatLng(node['lat'], node['lon']));
              }
            }
            
            String greenType = 'unknown';
            
            if (element['tags'].containsKey('leisure') && element['tags']['leisure'] == 'park') {
              greenType = 'park';
            } else if (element['tags'].containsKey('landuse')) {
              greenType = element['tags']['landuse'];
            } else if (element['tags'].containsKey('natural') && element['tags']['natural'] == 'wood') {
              greenType = 'forest';
            }
            
            parks.add({
              'id': element['id'],
              'type': greenType,
              'points': points,
              'tags': element['tags'],
              'elevation': 0.1, // Slight elevation for 2.5D effect
            });
          }
        }
        
        // Combine parks and trees
        final result = {
          'parks': parks,
          'trees': trees,
        };
        
        // Cache the processed data
        _dataCache[cacheKey] = result;
        return result;
      } else {
        debugPrint('Failed to fetch parks data: ${response.statusCode} - ${response.body}');
        _handleApiError('Failed to fetch parks data');
        return {};
      }
    } catch (e) {
      debugPrint('Error fetching parks data: $e');
      _handleApiError('Error fetching parks data');
      return {};
    }
  }
  
  /// Clears the data cache
  void clearCache() {
    _dataCache.clear();
  }

  // Helper for rotating through different endpoints
  void _rotateEndpoint() {
    // Track errors for this endpoint
    final currentEndpoint = _overpassEndpoints[_currentEndpointIndex];
    _endpointErrorCounts[currentEndpoint] = (_endpointErrorCounts[currentEndpoint] ?? 0) + 1;
    
    // Select the endpoint with the fewest errors
    if (_endpointErrorCounts.length > 1) {
      final sorted = _overpassEndpoints.toList()
        ..sort((a, b) => (_endpointErrorCounts[a] ?? 0).compareTo(_endpointErrorCounts[b] ?? 0));
      
      final bestEndpoint = sorted.first;
      _currentEndpointIndex = _overpassEndpoints.indexOf(bestEndpoint);
    } else {
      // Simple rotation if we don't have error stats yet
      _currentEndpointIndex = (_currentEndpointIndex + 1) % _overpassEndpoints.length;
    }
    
    debugPrint('Switching to Overpass endpoint: ${_overpassEndpoints[_currentEndpointIndex]}');
  }
  
  // Increment error counter and handle consecutive errors
  void _incrementErrorCounter() {
    _consecutiveErrors++;
    debugPrint('Consecutive API errors: $_consecutiveErrors');
    
    // If too many errors, rotate endpoints
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _rotateEndpoint();
    }
  }
} 