import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../../services/map_cache_manager.dart';

/// Extension methods for MapCacheManager to add functionality needed by OSM layers
extension MapCacheManagerExtension on MapCacheManager {
  /// In-memory cache for different data types
  static final Map<String, Map<String, dynamic>> _dataCache = {};
  
  /// Generate a unique cache key for data
  String generateCacheKey(
    String dataType,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel
  ) {
    final String latLngKey = '${southwest.latitude.toStringAsFixed(4)}_${southwest.longitude.toStringAsFixed(4)}_' +
                          '${northeast.latitude.toStringAsFixed(4)}_${northeast.longitude.toStringAsFixed(4)}';
    return '${dataType}_${latLngKey}_${zoomLevel.toStringAsFixed(1)}';
  }
  
  /// Check if data exists in the memory cache
  bool hasInMemoryCache(
    String dataType,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel
  ) {
    final key = generateCacheKey(dataType, southwest, northeast, zoomLevel);
    return _dataCache.containsKey(dataType) && _dataCache[dataType]!.containsKey(key);
  }
  
  /// Retrieve data from memory cache
  List<Map<String, dynamic>>? getFromMemoryCache(
    String dataType,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel
  ) {
    try {
      if (!hasInMemoryCache(dataType, southwest, northeast, zoomLevel)) {
        return null;
      }
      
      final key = generateCacheKey(dataType, southwest, northeast, zoomLevel);
      final cachedData = _dataCache[dataType]![key];
      
      if (cachedData is List) {
        return cachedData.cast<Map<String, dynamic>>();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error retrieving from memory cache: $e');
      return null;
    }
  }
  
  /// Store data in the memory cache
  void storeInMemoryCache(
    String dataType,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel,
    List<Map<String, dynamic>> data
  ) {
    try {
      final key = generateCacheKey(dataType, southwest, northeast, zoomLevel);
      
      // Ensure the data type exists in the cache
      _dataCache[dataType] ??= {};
      
      // Store the data
      _dataCache[dataType]![key] = data;
      
      // Limit cache size (remove oldest items if we have too many)
      _limitCacheSize(dataType, 20); // Keep at most 20 regions per data type
    } catch (e) {
      debugPrint('Error storing in memory cache: $e');
    }
  }
  
  /// Find a matching region in the cache
  String? findBestMatchingRegion(
    String dataType,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel
  ) {
    // Skip if no cache for this data type
    if (!_dataCache.containsKey(dataType)) {
      return null;
    }
    
    // Get the current bounds
    final currentBounds = _createBounds(southwest, northeast);
    final double currentZoom = zoomLevel;
    
    // Search for a close match
    String? bestMatch;
    double bestMatchArea = 0;
    
    for (final cacheKey in _dataCache[dataType]!.keys) {
      // Parse the cache key to get bounds info
      final parts = cacheKey.split('_');
      if (parts.length < 6) continue; // Skip invalid keys
      
      // Extract coordinates and zoom from the key
      try {
        final double swLat = double.parse(parts[1]);
        final double swLng = double.parse(parts[2]);
        final double neLat = double.parse(parts[3]);
        final double neLng = double.parse(parts[4]);
        final double zoom = double.parse(parts[5]);
        
        // Skip if zoom level is too different
        if ((zoom - currentZoom).abs() > 1.0) continue;
        
        // Create cached bounds
        final cachedBounds = _createBounds(
          LatLng(swLat, swLng),
          LatLng(neLat, neLng)
        );
        
        // Check if cached bounds contains or mostly overlaps with current bounds
        if (_boundsOverlap(cachedBounds, currentBounds)) {
          // Calculate overlap area
          final double overlapArea = _calculateOverlapArea(cachedBounds, currentBounds);
          
          // If better match, update
          if (bestMatch == null || overlapArea > bestMatchArea) {
            bestMatch = cacheKey;
            bestMatchArea = overlapArea;
          }
        }
      } catch (e) {
        // Skip invalid cache keys
        continue;
      }
    }
    
    return bestMatch;
  }
  
  /// Create a LatLngBounds object from southwest and northeast corners
  LatLngBounds _createBounds(LatLng southwest, LatLng northeast) {
    return LatLngBounds(southwest, northeast);
  }
  
  /// Check if two bounds overlap
  bool _boundsOverlap(LatLngBounds bounds1, LatLngBounds bounds2) {
    return !(
      bounds2.southWest.latitude > bounds1.northEast.latitude ||
      bounds2.northEast.latitude < bounds1.southWest.latitude ||
      bounds2.southWest.longitude > bounds1.northEast.longitude ||
      bounds2.northEast.longitude < bounds1.southWest.longitude
    );
  }
  
  /// Calculate area of overlap between two bounds
  double _calculateOverlapArea(LatLngBounds bounds1, LatLngBounds bounds2) {
    // Get overlap bounds
    final double south = math.max(bounds1.southWest.latitude, bounds2.southWest.latitude);
    final double north = math.min(bounds1.northEast.latitude, bounds2.northEast.latitude);
    final double west = math.max(bounds1.southWest.longitude, bounds2.southWest.longitude);
    final double east = math.min(bounds1.northEast.longitude, bounds2.northEast.longitude);
    
    // If there's no overlap, return 0
    if (south >= north || west >= east) return 0;
    
    // Calculate area (rough approximation)
    return (north - south) * (east - west);
  }
  
  /// Limit the cache size by removing oldest entries
  void _limitCacheSize(String dataType, int maxItems) {
    if (!_dataCache.containsKey(dataType)) return;
    
    final cache = _dataCache[dataType]!;
    if (cache.length <= maxItems) return;
    
    // Remove oldest items (this is a simple approach - a more sophisticated
    // approach would track access times and remove least recently used items)
    final keysToRemove = cache.keys.take(cache.length - maxItems).toList();
    for (final key in keysToRemove) {
      cache.remove(key);
    }
  }
} 