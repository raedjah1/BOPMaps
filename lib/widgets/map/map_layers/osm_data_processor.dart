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
    // Check if area is too large and reduce if necessary
    final areaSizeKm = _calculateAreaSizeInKm(southwest, northeast);
    LatLng sw = southwest;
    LatLng ne = northeast;
    
    // If area is too large, reduce to a reasonable size (1-2 square km)
    if (areaSizeKm > 2.0) {
      debugPrint('Area too large, reducing query size to center region');
      final center = LatLng(
        (southwest.latitude + northeast.latitude) / 2,
        (southwest.longitude + northeast.longitude) / 2,
      );
      
      // Calculate a smaller area around the center
      final latDelta = math.min(0.025, (northeast.latitude - southwest.latitude) / 2);
      final lngDelta = math.min(0.025, (northeast.longitude - southwest.longitude) / 2);
      
      sw = LatLng(center.latitude - latDelta, center.longitude - lngDelta);
      ne = LatLng(center.latitude + latDelta, center.longitude + lngDelta);
    }
    
    // Define a more efficient query for buildings, including levels data
    final query = '''
      [out:json][timeout:25];
      (
        way["building"]($sw.latitude,$sw.longitude,$ne.latitude,$ne.longitude);
        relation["building"]($sw.latitude,$sw.longitude,$ne.latitude,$ne.longitude);
      );
      out body;
      >;
      out skel qt;
    '''.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    final urlEncoded = Uri.encodeComponent(query);
    final url = 'https://overpass-api.de/api/interpreter?data=$urlEncoded';
    
    debugPrint('Fetching building data from $url for area: $sw.latitude,$sw.longitude,$ne.latitude,$ne.longitude');
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List<dynamic>;
        
        debugPrint('Received ${elements.length} building elements');
        
        // Process and return the buildings
        return _processBuildingElements(elements);
      } else {
        debugPrint('Error fetching building data: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception while fetching building data: $e');
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

  /// Fetches water bodies (lakes, rivers, etc.) from the Overpass API for a given bounding box
  Future<List<Map<String, dynamic>>> fetchWaterBodies(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for water bodies Overpass API query');
      return [];
    }
    
    final String cacheKey = 'water_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached water bodies data for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    if (timeSinceLastRequest < _minTimeBetweenRequests) {
      // Wait until we can make another request
      debugPrint('Throttling Overpass API request for water bodies, waiting for ${(_minTimeBetweenRequests - timeSinceLastRequest).inMilliseconds}ms');
      await Future.delayed(_minTimeBetweenRequests - timeSinceLastRequest);
    }
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      // If too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests for water bodies');
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
      
      debugPrint('Area too large for water bodies query, reducing size to center region');
    }
    
    // Construct Overpass API query for water bodies with proper syntax
    final String query = '''
      [out:json][timeout:25];
      (
        // Lakes and water areas
        way["natural"="water"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        relation["natural"="water"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Rivers
        way["waterway"="river"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["waterway"="stream"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Coastlines
        way["natural"="coastline"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching water bodies from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
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
        
        debugPrint('Received ${elements.length} water body elements');
        
        // Process water elements
        final List<Map<String, dynamic>> waterBodies = elements
            .where((element) => 
                (element['type'] == 'way' || element['type'] == 'relation') && 
                (element['tags'].containsKey('natural') || element['tags'].containsKey('waterway')))
            .map<Map<String, dynamic>>((water) {
              // Determine water type
              String waterType = 'unknown';
              double elevation = 0.0; // Water is flat in most cases
              
              if (water['tags'].containsKey('natural')) {
                waterType = water['tags']['natural'];
              } else if (water['tags'].containsKey('waterway')) {
                waterType = water['tags']['waterway'];
                
                // Rivers and streams should have a slight elevation for visual appeal
                if (waterType == 'river') {
                  elevation = 0.3;
                } else if (waterType == 'stream') {
                  elevation = 0.2;
                }
              }
              
              // Process geometry
              final List<LatLng> points = [];
              if (water.containsKey('geometry')) {
                for (final node in water['geometry']) {
                  points.add(LatLng(node['lat'], node['lon']));
                }
              }
              
              return {
                'id': water['id'],
                'type': waterType,
                'elevation': elevation,
                'points': points,
                'tags': water['tags'],
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = waterBodies;
        return waterBodies;
      } else {
        debugPrint('Failed to fetch water bodies: ${response.statusCode} - ${response.body}');
        _incrementErrorCounter();
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching water body data: $e');
      _incrementErrorCounter();
      return [];
    }
  }

  /// Fetches landscape features (parks, forests, etc.) from the Overpass API
  Future<List<Map<String, dynamic>>> fetchLandscapeFeatures(LatLng southwest, LatLng northeast) async {
    // Check for valid bounds
    if (southwest.latitude > northeast.latitude || southwest.longitude > northeast.longitude) {
      debugPrint('Invalid bounds provided for landscape features Overpass API query');
      return [];
    }
    
    final String cacheKey = 'landscape_${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    
    // Return cached data if available
    if (_dataCache.containsKey(cacheKey)) {
      debugPrint('Using cached landscape features for $cacheKey');
      return _dataCache[cacheKey];
    }
    
    // Throttle requests to avoid overloading the API
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    if (timeSinceLastRequest < _minTimeBetweenRequests) {
      // Wait until we can make another request
      debugPrint('Throttling Overpass API request for landscape, waiting for ${(_minTimeBetweenRequests - timeSinceLastRequest).inMilliseconds}ms');
      await Future.delayed(_minTimeBetweenRequests - timeSinceLastRequest);
    }
    
    // Check if we've had too many consecutive errors
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      // If too many errors, return empty data and try a different endpoint next time
      debugPrint('Too many consecutive errors, temporarily suspending OSM API requests for landscape');
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
      
      debugPrint('Area too large for landscape query, reducing size to center region');
    }
    
    // Construct Overpass API query for landscape features with proper syntax
    final String query = '''
      [out:json][timeout:25];
      (
        // Parks and green areas
        way["leisure"="park"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        relation["leisure"="park"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Forests and woods
        way["natural"="wood"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        relation["natural"="wood"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Grassland
        way["natural"="grassland"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        
        // Other natural features
        way["natural"="heath"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["natural"="scrub"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["landuse"="forest"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
        way["landuse"="meadow"](${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude});
      );
      out body geom;
    ''';
    
    try {
      _lastRequestTime = DateTime.now();
      
      // Get current endpoint
      final endpoint = _overpassEndpoints[_currentEndpointIndex];
      
      debugPrint('Fetching landscape features from $endpoint for area: ${newSW.latitude},${newSW.longitude},${newNE.latitude},${newNE.longitude}');
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
        
        debugPrint('Received ${elements.length} landscape features');
        
        // Process landscape elements
        final List<Map<String, dynamic>> landscapeFeatures = elements
            .where((element) => 
                (element['type'] == 'way' || element['type'] == 'relation') && 
                (element['tags'].containsKey('natural') || 
                 element['tags'].containsKey('leisure') || 
                 element['tags'].containsKey('landuse')))
            .map<Map<String, dynamic>>((feature) {
              // Determine feature type and characteristics
              String featureType = 'unknown';
              double elevation = 0.2; // Slight elevation for visual appeal
              
              if (feature['tags'].containsKey('natural')) {
                featureType = feature['tags']['natural'];
                
                // Adjust elevation based on natural feature type
                if (featureType == 'wood') {
                  elevation = 0.5; // Forests have more elevation
                }
              } else if (feature['tags'].containsKey('leisure')) {
                featureType = feature['tags']['leisure'];
              } else if (feature['tags'].containsKey('landuse')) {
                featureType = feature['tags']['landuse'];
                
                // Adjust elevation based on landuse
                if (featureType == 'forest') {
                  elevation = 0.5;
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
                'type': featureType,
                'elevation': elevation,
                'points': points,
                'tags': feature['tags'],
              };
            })
            .toList();
        
        // Cache the processed data
        _dataCache[cacheKey] = landscapeFeatures;
        return landscapeFeatures;
      } else {
        debugPrint('Failed to fetch landscape features: ${response.statusCode} - ${response.body}');
        _incrementErrorCounter();
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching landscape data: $e');
      _incrementErrorCounter();
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

  /// Calculate area size in square kilometers
  double _calculateAreaSizeInKm(LatLng sw, LatLng ne) {
    const earthRadius = 6371.0; // Earth's radius in km
    
    // Calculate width (longitude difference)
    final dLng = _toRadians(ne.longitude - sw.longitude);
    final widthAtLat = earthRadius * dLng * math.cos(_toRadians((sw.latitude + ne.latitude) / 2));
    
    // Calculate height (latitude difference)
    final dLat = _toRadians(ne.latitude - sw.latitude);
    final height = earthRadius * dLat;
    
    return widthAtLat * height;
  }
  
  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
  
  /// Process building elements from Overpass API response
  List<Map<String, dynamic>> _processBuildingElements(List<dynamic> elements) {
    final Map<int, Map<String, dynamic>> nodesMap = {};
    final List<Map<String, dynamic>> buildings = [];
    
    // First pass: collect all nodes
    for (final element in elements) {
      if (element['type'] == 'node') {
        nodesMap[element['id']] = {
          'lat': element['lat'],
          'lon': element['lon'],
        };
      }
    }
    
    // Second pass: process ways (buildings)
    for (final element in elements) {
      if (element['type'] == 'way' && element['tags']?['building'] != null) {
        final List<LatLng> points = [];
        final nodes = element['nodes'] as List<dynamic>;
        
        // Convert nodes to LatLng
        for (final nodeId in nodes) {
          final node = nodesMap[nodeId];
          if (node != null) {
            points.add(LatLng(node['lat'], node['lon']));
          }
        }
        
        // Only add if we have at least 3 points (to form a polygon)
        if (points.length >= 3) {
          // Get building attributes
          final tags = element['tags'] as Map<String, dynamic>;
          final buildingHeight = _getBuildingHeight(tags);
          final levels = _getBuildingLevels(tags);
          
          buildings.add({
            'id': element['id'],
            'points': points,
            'height': buildingHeight,
            'levels': levels,
            'type': tags['building'] ?? 'yes',
          });
        }
      }
    }
    
    return buildings;
  }
  
  /// Get building height from tags
  double _getBuildingHeight(Map<String, dynamic> tags) {
    // Try various height tags
    if (tags['height'] != null) {
      return _parseHeight(tags['height']);
    } else if (tags['building:height'] != null) {
      return _parseHeight(tags['building:height']);
    }
    
    // Estimate from levels if height not available
    final levels = _getBuildingLevels(tags);
    return levels * 3.0; // Assume 3 meters per level
  }
  
  /// Get building levels from tags
  double _getBuildingLevels(Map<String, dynamic> tags) {
    // Try various level tags
    if (tags['building:levels'] != null) {
      return _parseLevels(tags['building:levels']);
    } else if (tags['levels'] != null) {
      return _parseLevels(tags['levels']);
    }
    
    // Default to 1 level if not specified
    return 1.0;
  }
  
  /// Parse height value from string
  double _parseHeight(String height) {
    try {
      // Remove units and convert to double
      return double.parse(height.replaceAll(RegExp(r'[^\d\.]'), ''));
    } catch (e) {
      return 3.0; // Default height if parsing fails
    }
  }
  
  /// Parse levels value from string
  double _parseLevels(String levels) {
    try {
      return double.parse(levels);
    } catch (e) {
      return 1.0; // Default to 1 level if parsing fails
    }
  }
} 