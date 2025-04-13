import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A class to fetch and process OpenStreetMap data for 2.5D rendering
class OSMDataProcessor {
  // Cache for processed data to avoid redundant API calls
  final Map<String, dynamic> _dataCache = {};
  
  // Timeout duration for API requests
  final Duration _timeout = const Duration(seconds: 15);
  
  // API throttling control
  DateTime _lastRequestTime = DateTime.now().subtract(const Duration(seconds: 10));
  static const _minTimeBetweenRequests = Duration(seconds: 5); // Increased from 2 to 5 seconds
  int _consecutiveErrors = 0;
  static const _maxConsecutiveErrors = 3;
  
  // List of alternate Overpass API endpoints to try
  final List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
  ];
  int _currentEndpointIndex = 0;

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
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    if (timeSinceLastRequest < _minTimeBetweenRequests) {
      // Wait until we can make another request
      debugPrint('Throttling Overpass API request, waiting for ${(_minTimeBetweenRequests - timeSinceLastRequest).inMilliseconds}ms');
      await Future.delayed(_minTimeBetweenRequests - timeSinceLastRequest);
    }
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      // If too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests');
      _rotateEndpoint();
      
      // Schedule a reset of the error counter after some time
      Future.delayed(const Duration(seconds: 60), () {
        _consecutiveErrors = 0;
      });
      
      return [];
    }
    
    // Calculate area size
    final double latDelta = northeast.latitude - southwest.latitude;
    final double lonDelta = northeast.longitude - southwest.longitude;
    
    // If area is too large, focus on a smaller region to avoid overwhelming the API
    LatLng newSW = southwest;
    LatLng newNE = northeast;
    
    // Limit to about 0.05 degrees (approximately 5km)
    if (latDelta > 0.05 || lonDelta > 0.05) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.025,
        center.longitude - 0.025
      );
      
      newNE = LatLng(
        center.latitude + 0.025,
        center.longitude + 0.025
      );
      
      debugPrint('Area too large, reducing query size to center region');
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
        _consecutiveErrors = 0;
        
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
        _incrementErrorCounter();
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching building data: $e');
      _incrementErrorCounter();
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
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    if (timeSinceLastRequest < _minTimeBetweenRequests) {
      // Wait until we can make another request
      debugPrint('Throttling Overpass API request, waiting for ${(_minTimeBetweenRequests - timeSinceLastRequest).inMilliseconds}ms');
      await Future.delayed(_minTimeBetweenRequests - timeSinceLastRequest);
    }
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      // If too many errors, return empty data for some time
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
    
    // Limit to about 0.05 degrees (approximately 5km)
    if (latDelta > 0.05 || lonDelta > 0.05) {
      final LatLng center = LatLng(
        southwest.latitude + latDelta * 0.5,
        southwest.longitude + lonDelta * 0.5
      );
      
      newSW = LatLng(
        center.latitude - 0.025,
        center.longitude - 0.025
      );
      
      newNE = LatLng(
        center.latitude + 0.025,
        center.longitude + 0.025
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
        _consecutiveErrors = 0;
        
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
        _incrementErrorCounter();
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching road data: $e');
      _incrementErrorCounter();
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

  /// Clears the data cache
  void clearCache() {
    _dataCache.clear();
  }

  // Helper method to increment error counter
  void _incrementErrorCounter() {
    _consecutiveErrors++;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _rotateEndpoint();
    }
  }
  
  // Rotate to next endpoint when errors occur
  void _rotateEndpoint() {
    _currentEndpointIndex = (_currentEndpointIndex + 1) % _overpassEndpoints.length;
    debugPrint('Switching to Overpass API endpoint: ${_overpassEndpoints[_currentEndpointIndex]}');
  }
} 