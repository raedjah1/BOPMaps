import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'persistent_map_cache.dart';

/// Types of map data that can be cached
enum MapDataType {
  buildings,
  roads,
  parks,
  water,
  poi,
  terrain,
  vectorTiles,
  rasterTiles,
  styles,
}

/// Extension to convert enum to string for storage
extension MapDataTypeExtension on MapDataType {
  String get value {
    return toString().split('.').last;
  }
}

/// Class to coordinate caching strategies for map data
class MapCacheCoordinator {
  // Singleton instance
  static final MapCacheCoordinator _instance = MapCacheCoordinator._internal();
  factory MapCacheCoordinator() => _instance;
  
  // Persistent cache
  final PersistentMapCache _persistentCache = PersistentMapCache();
  
  // Memory cache for different zoom levels
  final Map<int, Map<String, dynamic>> _zoomLevelCache = {};
  
  // Cache prefetch queue
  final _prefetchQueue = <_PrefetchRequest>[];
  bool _isPrefetching = false;
  
  // Cache preload status
  bool _isPreloading = false;
  final _preloadCompleter = Completer<void>();
  
  // Cache statistics
  int _requestCount = 0;
  int _cacheHits = 0;
  final _typeCounts = <MapDataType, int>{};
  
  // Debouncer for prefetch operations
  Timer? _prefetchDebounceTimer;
  
  // Maximum memory cache size per zoom level (in items)
  static const int _maxMemoryCacheItemsPerZoomLevel = 50;
  
  // OSM API Request limits - to avoid exceeding Overpass API quotas
  static const Duration _minTimeBetweenRequests = Duration(seconds: 10);
  DateTime _lastRequestTime = DateTime.now().subtract(Duration(seconds: 30));
  
  // Private constructor
  MapCacheCoordinator._internal();
  
  /// Initialize the cache coordinator
  Future<void> initialize() async {
    await _persistentCache.initialized;
    
    // Preload critical data
    _preloadCriticalData();
  }
  
  /// Preload critical map data in the background
  void _preloadCriticalData() async {
    if (_isPreloading) return;
    
    _isPreloading = true;
    
    try {
      // Load map styles and other critical data here
      // This runs in the background after app startup to ensure
      // commonly used data is ready
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      _preloadCompleter.complete();
    } catch (e) {
      debugPrint('Error preloading critical map data: $e');
      _preloadCompleter.completeError(e);
    } finally {
      _isPreloading = false;
    }
  }
  
  /// Calculate a cache key for a geographic region
  String _calculateRegionKey(MapDataType type, LatLng southwest, LatLng northeast, [double? zoomLevel]) {
    // Round coordinates to reduce cache fragmentation
    final sw = _roundCoordinates(southwest);
    final ne = _roundCoordinates(northeast);
    
    final zoomPart = zoomLevel != null ? '_zoom${zoomLevel.round()}' : '';
    return '${type.value}_${sw.latitude}_${sw.longitude}_${ne.latitude}_${ne.longitude}$zoomPart';
  }
  
  /// Round coordinates to reduce cache fragmentation
  LatLng _roundCoordinates(LatLng coord) {
    // Round to ~10m precision for caching purposes
    return LatLng(
      (coord.latitude * 1000).round() / 1000,
      (coord.longitude * 1000).round() / 1000,
    );
  }
  
  /// Get the zoom bucket (0-5) for a zoom level
  int _getZoomBucket(double zoomLevel) {
    if (zoomLevel < 6) return 0;  // Global view
    if (zoomLevel < 9) return 1;  // Continental view
    if (zoomLevel < 12) return 2; // Country view
    if (zoomLevel < 15) return 3; // Region/city view
    if (zoomLevel < 18) return 4; // Neighborhood view
    return 5;                     // Street view
  }
  
  /// Ensure enough time has passed between API requests to avoid rate limiting
  Future<void> _throttleRequests() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    
    if (timeSinceLastRequest < _minTimeBetweenRequests) {
      // Wait until we can make another request
      final waitTime = _minTimeBetweenRequests - timeSinceLastRequest;
      await Future.delayed(waitTime);
    }
    
    _lastRequestTime = DateTime.now();
  }
  
  /// Get data from memory cache for a specific zoom bucket
  dynamic _getFromZoomLevelCache(MapDataType type, String key, int zoomBucket) {
    if (_zoomLevelCache.containsKey(zoomBucket)) {
      final zoomCache = _zoomLevelCache[zoomBucket]!;
      final fullKey = '${type.value}_$key';
      
      if (zoomCache.containsKey(fullKey)) {
        return zoomCache[fullKey];
      }
    }
    return null;
  }
  
  /// Store data in memory cache for a specific zoom bucket
  void _storeInZoomLevelCache(MapDataType type, String key, dynamic data, int zoomBucket) {
    // Initialize the zoom level cache if it doesn't exist
    _zoomLevelCache.putIfAbsent(zoomBucket, () => {});
    
    final zoomCache = _zoomLevelCache[zoomBucket]!;
    final fullKey = '${type.value}_$key';
    
    // Store data
    zoomCache[fullKey] = data;
    
    // Check if we need to prune this zoom level's cache
    if (zoomCache.length > _maxMemoryCacheItemsPerZoomLevel) {
      // Remove oldest 20% of entries to make room
      final keysToRemove = zoomCache.keys.take(zoomCache.length ~/ 5).toList();
      for (final k in keysToRemove) {
        zoomCache.remove(k);
      }
      debugPrint('Pruned ${keysToRemove.length} entries from zoom level $zoomBucket cache');
    }
  }
  
  /// Get data from cache
  Future<dynamic> getData({
    required MapDataType type,
    required String key,
    LatLng? southwest,
    LatLng? northeast,
    double? zoomLevel,
    FutureOr<dynamic> Function()? fetchIfMissing,
  }) async {
    _requestCount++;
    _typeCounts[type] = (_typeCounts[type] ?? 0) + 1;
    
    // If we have zoom level information, use the appropriate zoom bucket
    int? zoomBucket;
    if (zoomLevel != null) {
      zoomBucket = _getZoomBucket(zoomLevel);
      
      // Check memory cache for this zoom bucket first
      final zoomCacheData = _getFromZoomLevelCache(type, key, zoomBucket);
      if (zoomCacheData != null) {
        _cacheHits++;
        return zoomCacheData;
      }
    }
    
    // Check for data in persistent cache
    final data = await _persistentCache.getMapData(
      dataType: type.value,
      key: key,
    );
    
    if (data != null) {
      _cacheHits++;
      
      // Also store in zoom level cache if we have zoom information
      if (zoomBucket != null) {
        _storeInZoomLevelCache(type, key, data, zoomBucket);
      }
      
      return data;
    }
    
    // Data not found in cache, fetch it if requested
    if (fetchIfMissing != null) {
      // Throttle API requests to avoid rate limiting
      await _throttleRequests();
      
      final fetchedData = await fetchIfMissing();
      
      // Store fetched data in cache
      if (fetchedData != null) {
        // Store in persistent cache
        unawaited(_persistentCache.storeMapData(
          dataType: type.value,
          key: key,
          data: fetchedData,
        ));
        
        // Also store in zoom level cache if we have zoom information
        if (zoomBucket != null) {
          _storeInZoomLevelCache(type, key, fetchedData, zoomBucket);
        }
      }
      
      return fetchedData;
    }
    
    return null;
  }
  
  /// Store data in cache
  Future<void> storeData({
    required MapDataType type,
    required String key,
    required dynamic data,
    Map<String, dynamic>? metadata,
    double? zoomLevel,
  }) async {
    // Store in persistent cache
    await _persistentCache.storeMapData(
      dataType: type.value,
      key: key,
      data: data,
      metadata: metadata,
    );
    
    // If we have zoom level information, also store in memory cache
    if (zoomLevel != null) {
      final zoomBucket = _getZoomBucket(zoomLevel);
      _storeInZoomLevelCache(type, key, data, zoomBucket);
    }
  }
  
  /// Check if a region cache exists for a larger area that contains the requested area
  Future<Map<String, dynamic>?> findOverlappingRegionData(
    MapDataType type,
    LatLng southwest,
    LatLng northeast,
    double zoomLevel,
  ) async {
    // First check memory cache
    final zoomBucket = _getZoomBucket(zoomLevel);
    if (_zoomLevelCache.containsKey(zoomBucket)) {
      final zoomCache = _zoomLevelCache[zoomBucket]!;
      
      // Find cached regions that fully contain our region
      for (final entry in zoomCache.entries) {
        if (entry.key.startsWith('${type.value}_')) {
          // Extract coordinates from cache key
          final parts = entry.key.split('_');
          if (parts.length >= 5) {
            try {
              final cachedSW = LatLng(double.parse(parts[2]), double.parse(parts[3]));
              final cachedNE = LatLng(double.parse(parts[4]), double.parse(parts[5]));
              
              // Check if cached region fully contains our region
              if (cachedSW.latitude <= southwest.latitude &&
                  cachedSW.longitude <= southwest.longitude &&
                  cachedNE.latitude >= northeast.latitude &&
                  cachedNE.longitude >= northeast.longitude) {
                
                return entry.value;
              }
            } catch (e) {
              // Skip malformed keys
            }
          }
        }
      }
    }
    
    // TODO: Check persistent cache for overlapping regions
    
    return null;
  }
  
  /// Check if data exists in cache
  Future<bool> hasData({
    required MapDataType type,
    required String key,
    double? zoomLevel,
  }) async {
    // If we have zoom level information, check the appropriate zoom bucket first
    if (zoomLevel != null) {
      final zoomBucket = _getZoomBucket(zoomLevel);
      final zoomCacheData = _getFromZoomLevelCache(type, key, zoomBucket);
      if (zoomCacheData != null) {
        return true;
      }
    }
    
    // Check persistent cache
    return await _persistentCache.hasMapData(
      dataType: type.value,
      key: key,
    );
  }
  
  /// Prefetch data for a geographic region
  void prefetchDataForRegion({
    required LatLng southwest,
    required LatLng northeast,
    required List<MapDataType> dataTypes,
    required int minZoom,
    required int maxZoom,
    PrefetchPriority priority = PrefetchPriority.normal,
  }) {
    // Debounce multiple calls to prefetch
    _prefetchDebounceTimer?.cancel();
    _prefetchDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _addToPrefetchQueue(
        southwest: southwest,
        northeast: northeast,
        dataTypes: dataTypes,
        minZoom: minZoom,
        maxZoom: maxZoom,
        priority: priority,
      );
    });
  }
  
  /// Add a request to the prefetch queue
  void _addToPrefetchQueue({
    required LatLng southwest,
    required LatLng northeast,
    required List<MapDataType> dataTypes,
    required int minZoom,
    required int maxZoom,
    required PrefetchPriority priority,
  }) {
    // Create a prefetch request
    final request = _PrefetchRequest(
      southwest: southwest,
      northeast: northeast,
      dataTypes: dataTypes,
      minZoom: minZoom,
      maxZoom: maxZoom,
      priority: priority,
    );
    
    // Add to queue with proper priority
    if (priority == PrefetchPriority.high) {
      _prefetchQueue.insert(0, request);
    } else {
      _prefetchQueue.add(request);
    }
    
    // Start prefetching if not already running
    if (!_isPrefetching) {
      _startPrefetching();
    }
  }
  
  /// Start processing the prefetch queue
  void _startPrefetching() async {
    if (_isPrefetching || _prefetchQueue.isEmpty) return;
    
    _isPrefetching = true;
    
    while (_prefetchQueue.isNotEmpty) {
      final request = _prefetchQueue.removeAt(0);
      await _processPrefetchRequest(request);
      
      // Pause between requests to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _isPrefetching = false;
  }
  
  /// Process a single prefetch request
  Future<void> _processPrefetchRequest(_PrefetchRequest request) async {
    // This would call specific prefetch methods for each data type
    // Implementation depends on the data structures and APIs used
    
    for (final type in request.dataTypes) {
      switch (type) {
        case MapDataType.buildings:
          // Prefetch buildings data
          // API calls would happen here, results stored in cache
          break;
        case MapDataType.roads:
          // Prefetch roads data
          break;
        case MapDataType.vectorTiles:
          // Prefetch vector tiles
          await _prefetchVectorTiles(
            request.southwest,
            request.northeast,
            request.minZoom,
            request.maxZoom,
          );
          break;
        default:
          // Handle other data types
          break;
      }
    }
  }
  
  /// Prefetch vector tiles for a region
  Future<void> _prefetchVectorTiles(
    LatLng southwest,
    LatLng northeast,
    int minZoom,
    int maxZoom,
  ) async {
    // This is a placeholder - actual implementation would:
    // 1. Calculate tile coordinates for the bounding box at each zoom level
    // 2. Download tiles that aren't already cached
    // 3. Store them in the cache
    
    // For demonstration purposes only
    debugPrint('Prefetching vector tiles from zoom $minZoom to $maxZoom');
    
    // We would typically iterate through zoom levels and tile coordinates
    for (int z = minZoom; z <= maxZoom; z++) {
      // Calculate tile ranges for this zoom level
      // This is just pseudocode - actual calculation would be more complex
      final int minX = _lon2tile(southwest.longitude, z);
      final int maxX = _lon2tile(northeast.longitude, z);
      final int minY = _lat2tile(northeast.latitude, z);
      final int maxY = _lat2tile(southwest.latitude, z);
      
      // Limit the number of tiles we prefetch to avoid overwhelming the system
      final int maxTiles = 16;  // Arbitrary limit
      final int xRange = maxX - minX + 1;
      final int yRange = maxY - minY + 1;
      
      if (xRange * yRange > maxTiles) {
        debugPrint('Too many tiles to prefetch at zoom $z: ${xRange * yRange} > $maxTiles');
        continue;
      }
      
      // Prefetch tiles
      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          final key = 'z${z}_x${x}_y$y';
          
          // Check if we already have this tile
          final tileExists = await hasData(
            type: MapDataType.vectorTiles,
            key: key,
            zoomLevel: z.toDouble(),
          );
          
          if (!tileExists) {
            // Here we would make an API call to fetch the tile
            // and then store it in the cache
            // This is placeholder code
            debugPrint('Would prefetch tile $key');
          }
        }
      }
    }
  }
  
  // Helper methods to convert between coordinates and tile numbers
  // Based on OSM slippy map math: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
  int _lon2tile(double lon, int z) {
    return ((lon + 180) / 360 * (1 << z)).floor();
  }
  
  int _lat2tile(double lat, int z) {
    final double latRad = lat * (math.pi / 180);
    return ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * (1 << z)).floor();
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final persistentStats = _persistentCache.getCacheStats();
    
    return {
      'requests': _requestCount,
      'hits': _cacheHits,
      'hit_rate': _requestCount > 0 ? _cacheHits / _requestCount : 0.0,
      'by_type': _typeCounts.map((k, v) => MapEntry(k.value, v)),
      'persistent': persistentStats,
      'prefetch_queue_size': _prefetchQueue.length,
      'zoom_levels_cached': _zoomLevelCache.keys.toList(),
      'memory_cache_items': _zoomLevelCache.map((k, v) => MapEntry(k.toString(), v.length)),
    };
  }
  
  /// Clear all cached data
  Future<void> clearAll() async {
    await _persistentCache.clearAllCaches();
    _zoomLevelCache.clear();
    _requestCount = 0;
    _cacheHits = 0;
    _typeCounts.clear();
  }
  
  /// Clear cached data for a specific type
  Future<void> clearType(MapDataType type) async {
    await _persistentCache.clearCacheForType(type.value);
    
    // Also clear from memory cache
    for (final zoomBucket in _zoomLevelCache.keys) {
      final cache = _zoomLevelCache[zoomBucket]!;
      cache.removeWhere((key, _) => key.startsWith('${type.value}_'));
    }
    
    _typeCounts[type] = 0;
  }
}

/// Prefetch priority levels
enum PrefetchPriority {
  low,
  normal,
  high,
}

/// Internal class for prefetch requests
class _PrefetchRequest {
  final LatLng southwest;
  final LatLng northeast;
  final List<MapDataType> dataTypes;
  final int minZoom;
  final int maxZoom;
  final PrefetchPriority priority;
  
  _PrefetchRequest({
    required this.southwest,
    required this.northeast,
    required this.dataTypes,
    required this.minZoom,
    required this.maxZoom,
    required this.priority,
  });
}

// Allow futures to run without waiting
void unawaited(Future<void> future) {
  future.then((_) {
    // Do nothing
  }).catchError((error) {
    debugPrint('Unawaited future completed with error: $error');
  });
} 