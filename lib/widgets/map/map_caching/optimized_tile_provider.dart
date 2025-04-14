import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../../../services/map_cache_manager.dart';

/// An optimized tile provider that implements multi-level caching and
/// preloading for better map performance at different zoom levels.
/// Enhanced with connection pooling, rate limiting and error handling.
class OptimizedTileProvider extends TileProvider {
  final String urlTemplate;
  final Map<String, String>? headers;
  final TileLayer tileLayer;
  
  // Map cache manager for advanced caching and offline support
  final MapCacheManager _mapCacheManager = MapCacheManager();
  
  // Tile cache in memory for fast access
  final Map<String, Uint8List> _memoryCache = {};
  
  // Keep track of which tiles are currently being fetched to avoid duplicates
  final Set<String> _tilesInProgress = {};
  
  // Keep track of the current viewport for preloading
  LatLngBounds? _currentViewport;
  double _currentZoom = 0;
  
  // Connection state tracking
  bool _isOffline = false;
  DateTime _lastConnectivityCheck = DateTime.now();
  int _consecutiveNetworkFailures = 0;
  
  // Preloading configuration
  final bool enablePreloading;
  final int preloadRadius;
  
  // Connection pooling and rate limiting
  final int _maxConcurrentConnections = 8;
  int _activeConnections = 0;
  final _connectionQueue = <_QueuedTileRequest>[];
  
  // Request cancellation support
  final Map<String, Completer<Uint8List?>> _requestCompleters = {};
  
  // Fallback tile for when loading fails
  Uint8List? _fallbackTile;
  
  // Rate limiting
  final Map<String, DateTime> _lastHostRequest = {};
  final Map<String, int> _hostErrorCount = {};
  final int _minRequestInterval = 50; // ms between requests to same host
  
  // Retry configuration
  final int _maxRetries = 3;
  final Map<String, int> _retryCount = {};
  
  // Server rotation for OpenStreetMap (a,b,c subdomains)
  int _serverIndex = 0;
  final List<String> _subdomains = ['a', 'b', 'c'];
  
  // Quality configuration per zoom level
  final Map<int, double> _qualityByZoomLevel = {
    // Zoom level : JPEG quality (higher = better quality but larger files)
    0: 60,  // World level - lowest quality
    1: 60,
    2: 60,
    3: 60,
    4: 65,
    5: 65,
    6: 70,  // Continental level
    7: 70,
    8: 75,
    9: 75,
    10: 80, // Country level
    11: 80,
    12: 85,
    13: 85,
    14: 90, // City level
    15: 90,
    16: 95,
    17: 95,
    18: 100, // Street level
    19: 100,
    20: 100,
  };
  
  OptimizedTileProvider({
    required this.urlTemplate,
    this.headers,
    required this.tileLayer,
    this.enablePreloading = true,
    this.preloadRadius = 1,
  }) {
    _initialize();
  }
  
  // Initialize the provider
  Future<void> _initialize() async {
    // Initialize the cache manager
    await _mapCacheManager.initialize();
    
    // Create the fallback tile
    _initializeFallbackTile();
    
    // Start the connection queue processor
    _processQueue();
    
    // Monitor network state
    _monitorNetworkState();
  }
  
  // Create a blank fallback tile
  Future<void> _initializeFallbackTile() async {
    try {
      // Try to get fallback tile from cache manager first
      final fallbackFromCache = await _mapCacheManager.getFallbackTile();
      if (fallbackFromCache != null) {
        _fallbackTile = fallbackFromCache;
        return;
      }

      // Create a 256x256 white tile with a thin grid
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Fill with very light gray background
      final paint = Paint()
        ..color = const Color(0xFFF0F0F0);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 256, 256), paint);
      
      // Draw a grid
      final gridPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 1.0;
      
      // Draw horizontal lines
      for (int i = 0; i < 256; i += 64) {
        canvas.drawLine(
          Offset(0, i.toDouble()),
          Offset(256, i.toDouble()),
          gridPaint,
        );
      }
      
      // Draw vertical lines
      for (int i = 0; i < 256; i += 64) {
        canvas.drawLine(
          Offset(i.toDouble(), 0),
          Offset(i.toDouble(), 256),
          gridPaint,
        );
      }
      
      final picture = recorder.endRecording();
      final img = await picture.toImage(256, 256);
      final byteData = await img.toByteData(format: ImageByteFormat.png);
      
      if (byteData != null) {
        _fallbackTile = byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error creating fallback tile: $e');
      // Create a simple blank white tile as backup
      _fallbackTile = Uint8List.fromList(List.filled(256 * 256 * 4, 255));
    }
  }

  // Periodically check network state
  Future<void> _monitorNetworkState() async {
    while (true) {
      // Wait before checking again
      await Future.delayed(const Duration(seconds: 5));
      
      // Check if we should update the network state
      if (DateTime.now().difference(_lastConnectivityCheck).inSeconds >= 30) {
        _checkConnectivity();
      }
      
      // Clean up memory cache periodically
      _cleanupMemoryCache();
    }
  }
  
  // Check network connectivity
  Future<void> _checkConnectivity() async {
    _lastConnectivityCheck = DateTime.now();
    
    try {
      // Try to connect to a reliable service like Google DNS
      final result = await http.get(Uri.parse('https://8.8.8.8'), 
        headers: {'Connection': 'close'}).timeout(const Duration(seconds: 5));
      
      if (result.statusCode >= 200 && result.statusCode < 300) {
        // Connection successful
        if (_isOffline) {
          debugPrint('Network connection restored');
          _isOffline = false;
          _consecutiveNetworkFailures = 0;
        }
      } else {
        _handlePossibleOfflineState();
      }
    } catch (e) {
      _handlePossibleOfflineState();
    }
  }
  
  // Handle possible offline state
  void _handlePossibleOfflineState() {
    _consecutiveNetworkFailures++;
    
    // If we've had several failures, consider the device offline
    if (_consecutiveNetworkFailures >= 3 && !_isOffline) {
      debugPrint('Network appears to be offline');
      _isOffline = true;
    }
  }
  
  // Cleanup memory cache to prevent excessive memory usage
  void _cleanupMemoryCache() {
    // If we have more than 200 tiles in memory, remove oldest ones
    if (_memoryCache.length > 200) {
      final keysToRemove = _memoryCache.keys.take(_memoryCache.length - 150).toList();
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
      }
    }
  }
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tileKey = _generateTileKey(coordinates);
    
    // Cancel any previous loading requests for this tile if it's being loaded again
    // This happens when rapidly zooming in/out
    _cancelPreviousRequest(tileKey);
    
    // Update current viewport for preloading
    _updateViewport(options);
    
    // Check if the tile is already in memory
    if (_memoryCache.containsKey(tileKey)) {
      return MemoryImage(_memoryCache[tileKey]!);
    }
    
    // Create a network image provider that uses our caching logic
    return OptimizedNetworkImageProvider(
      coordinates: coordinates,
      urlTemplate: urlTemplate,
      headers: headers,
      tileProvider: this,
      tileKey: tileKey,
    );
  }
  
  // Check if a tile is available in the map cache
  Future<Uint8List?> _checkMapCache(TileCoordinates coordinates, TileLayer options) async {
    try {
      return await _mapCacheManager.getCachedTile(coordinates, options);
    } catch (e) {
      debugPrint('Error checking map cache: $e');
      return null;
    }
  }
  
  // Cancel previous request for this tile if it exists
  void _cancelPreviousRequest(String tileKey) {
    if (_requestCompleters.containsKey(tileKey)) {
      _requestCompleters[tileKey]?.completeError(
        Exception('Request cancelled due to new request for same tile')
      );
      _requestCompleters.remove(tileKey);
      _tilesInProgress.remove(tileKey);
    }
  }
  
  // Cancel all non-essential requests (e.g., during rapid movement or network issues)
  void cancelNonEssentialRequests() {
    // Make a copy of keys to avoid concurrent modification
    final keys = List<String>.from(_requestCompleters.keys);
    
    // Cancel all non-priority requests
    for (final key in keys) {
      // Find if this is a priority request - we'd need to track this in _tilesInProgress
      // For now, cancel all to be safe
      _cancelPreviousRequest(key);
    }
    
    // Clear the connection queue
    _connectionQueue.clear();
  }
  
  // Update viewport information for preloading
  void _updateViewport(TileLayer options) {
    final map = options.controller?.camera;
    if (map != null) {
      _currentViewport = map.visibleBounds;
      _currentZoom = map.zoom;
      
      // Trigger preloading if enabled
      if (enablePreloading && !_isOffline) {
        _preloadTiles(options);
      }
    }
  }
  
  // Preload tiles around the current viewport with limited concurrency
  void _preloadTiles(TileLayer options) async {
    if (_currentViewport == null) return;
    
    // Get visible tile range
    final zoom = _currentZoom.ceil();
    final sw = _currentViewport!.southWest;
    final ne = _currentViewport!.northEast;
    
    // Convert to tile coordinates
    final swTile = _latLngToTileCoordinates(sw, zoom);
    final neTile = _latLngToTileCoordinates(ne, zoom);
    
    // Expand by preload radius, but limit to visible area plus a small margin
    final minX = (swTile.x - preloadRadius).clamp(0, math.pow(2, zoom).toInt() - 1);
    final maxX = (neTile.x + preloadRadius).clamp(0, math.pow(2, zoom).toInt() - 1);
    final minY = (swTile.y - preloadRadius).clamp(0, math.pow(2, zoom).toInt() - 1);
    final maxY = (neTile.y + preloadRadius).clamp(0, math.pow(2, zoom).toInt() - 1);
    
    // Calculate center of viewport for prioritization
    final centerX = (swTile.x + neTile.x) ~/ 2;
    final centerY = (swTile.y + neTile.y) ~/ 2;
    
    // Build a prioritized list of tiles
    final tilesToLoad = <_PrioritizedTileRequest>[];
    
    // First load tiles in the current viewport (priority 0)
    for (int x = swTile.x; x <= neTile.x; x++) {
      for (int y = swTile.y; y <= neTile.y; y++) {
        final coords = TileCoordinates(x: x, y: y, z: zoom);
        final tileKey = _generateTileKey(coords);
        
        // Skip if already cached or in progress
        if (_memoryCache.containsKey(tileKey) || _tilesInProgress.contains(tileKey)) {
          continue;
        }
        
        // Calculate distance from center for priority
        final distance = math.sqrt(math.pow(x - centerX, 2) + math.pow(y - centerY, 2));
        tilesToLoad.add(_PrioritizedTileRequest(coords, distance.toInt()));
      }
    }
    
    // Then sort tiles by distance from center
    tilesToLoad.sort((a, b) => a.priority.compareTo(b.priority));
    
    // Queue up to a reasonable number of tiles to avoid overwhelming the system
    int count = 0;
    final maxTilesToQueue = 50; // Limit preloading to prevent excessive memory use
    
    for (final tileRequest in tilesToLoad) {
      if (count >= maxTilesToQueue) break;
      
      final tileKey = _generateTileKey(tileRequest.coordinates);
      
      // Double check it's not already being loaded (could have changed since we created the list)
      if (!_tilesInProgress.contains(tileKey) && !_memoryCache.containsKey(tileKey)) {
        _queueTileRequest(tileRequest.coordinates, isPriority: false);
        count++;
      }
    }
  }
  
  // Queue a tile request to be processed when a connection slot is available
  void _queueTileRequest(TileCoordinates coordinates, {bool isPriority = true}) {
    final tileKey = _generateTileKey(coordinates);
    
    // Create a completer that will be resolved when the tile is loaded
    final completer = Completer<Uint8List?>();
    _requestCompleters[tileKey] = completer;
    
    // Mark this tile as in progress
    _tilesInProgress.add(tileKey);
    
    // Add to the queue with appropriate priority
    _connectionQueue.add(_QueuedTileRequest(
      coordinates: coordinates,
      isPriority: isPriority,
      createdAt: DateTime.now(),
      tileKey: tileKey,
    ));
    
    // Sort the queue by priority and creation time
    _sortConnectionQueue();
  }
  
  // Process the connection queue
  Future<void> _processQueue() async {
    // Run this continuously
    while (true) {
      // If we're offline, wait a bit longer between checks
      final waitTime = _isOffline ? 500 : 50;
      
      // Limit number of concurrent connections
      if (_activeConnections < _maxConcurrentConnections && _connectionQueue.isNotEmpty) {
        final request = _connectionQueue.removeAt(0);
        _activeConnections++;
        
        // Process the request
        _loadTileFromNetwork(request.coordinates).then((data) {
          // Resolve the request completer
          if (_requestCompleters.containsKey(request.tileKey)) {
            if (!_requestCompleters[request.tileKey]!.isCompleted) {
              _requestCompleters[request.tileKey]!.complete(data);
            }
            _requestCompleters.remove(request.tileKey);
          }
          
          // Mark this request as done
          _tilesInProgress.remove(request.tileKey);
          _activeConnections--;
        }).catchError((e) {
          // Handle error - if we have a completer, complete with error
          if (_requestCompleters.containsKey(request.tileKey)) {
            if (!_requestCompleters[request.tileKey]!.isCompleted) {
              _requestCompleters[request.tileKey]!.completeError(e);
            }
            _requestCompleters.remove(request.tileKey);
          }
          
          // Mark this request as done
          _tilesInProgress.remove(request.tileKey);
          _activeConnections--;
        });
      }
      
      // Clean up old/stale requests that have been in the queue too long
      final now = DateTime.now();
      _connectionQueue.removeWhere((request) => 
        now.difference(request.createdAt).inSeconds > 30 // Remove requests older than 30 seconds
      );
      
      // Wait a bit before checking the queue again
      await Future.delayed(Duration(milliseconds: waitTime));
    }
  }
  
  // Sort connection queue by priority
  void _sortConnectionQueue() {
    _connectionQueue.sort((a, b) {
      // First sort by priority
      if (a.isPriority != b.isPriority) {
        return a.isPriority ? -1 : 1;
      }
      // Then by creation time (older first)
      return a.createdAt.compareTo(b.createdAt);
    });
  }
  
  // Convert LatLng to tile coordinates
  TileCoordinates _latLngToTileCoordinates(LatLng latLng, int zoom) {
    final lat = latLng.latitude;
    final lng = latLng.longitude;
    
    final x = ((lng + 180) / 360 * math.pow(2, zoom)).floor();
    final y = ((1 - math.log(math.tan(lat * math.pi / 180) + 1 / math.cos(lat * math.pi / 180)) / math.pi) / 2 * math.pow(2, zoom)).floor();
    
    return TileCoordinates(x: x, y: y, z: zoom);
  }
  
  // Generate a consistent key for a tile
  String _generateTileKey(TileCoordinates coordinates) {
    return 'tile_${coordinates.z}_${coordinates.x}_${coordinates.y}';
  }
  
  // Extract hostname from URL
  String _extractHostname(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url.split('/')[2];
    }
  }
  
  // Check if we need to rate limit requests to this host
  bool _shouldRateLimit(String host) {
    // If we've had errors with this host, increase backoff
    final errorCount = _hostErrorCount[host] ?? 0;
    final backoffMultiplier = math.pow(2, math.min(errorCount, 5)).toInt();
    final interval = _minRequestInterval * backoffMultiplier;
    
    // Check when we last made a request to this host
    final lastRequest = _lastHostRequest[host];
    if (lastRequest != null) {
      final timeSince = DateTime.now().difference(lastRequest).inMilliseconds;
      return timeSince < interval;
    }
    
    return false;
  }
  
  // Update the last request time for a host
  void _updateLastRequestTime(String host) {
    _lastHostRequest[host] = DateTime.now();
  }
  
  // Get the next server subdomain in rotation
  String _getNextSubdomain() {
    final subdomain = _subdomains[_serverIndex];
    _serverIndex = (_serverIndex + 1) % _subdomains.length;
    return subdomain;
  }
  
  // Load a tile from network with retry and backoff logic
  Future<Uint8List?> _loadTileFromNetwork(TileCoordinates coordinates) async {
    final tileKey = _generateTileKey(coordinates);
    final z = coordinates.z;
    final x = coordinates.x;
    final y = coordinates.y;
    
    // If we're in offline mode, don't even try the network
    if (_isOffline) {
      return _fallbackTile;
    }
    
    // First check map cache system for the tile
    final cachedTile = await _checkMapCache(coordinates, tileLayer);
    if (cachedTile != null) {
      _memoryCache[tileKey] = cachedTile;
      return cachedTile;
    }
    
    // Format URL using the template and subdomain rotation for load balancing
    var url = urlTemplate
        .replaceAll('{z}', z.toString())
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString());
        
    // Rotate servers if this is an OSM URL
    if (url.contains('{s}')) {
      url = url.replaceAll('{s}', _getNextSubdomain());
    }
    
    // Get the hostname for rate limiting
    final host = _extractHostname(url);
    
    // Check if we need to rate limit
    if (_shouldRateLimit(host)) {
      // Wait a bit before trying again
      await Future.delayed(Duration(milliseconds: _minRequestInterval));
    }
    
    // Mark this request
    _updateLastRequestTime(host);
    
    try {
      // Download the tile
      final response = await http.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Reset error count for this host on success
        _hostErrorCount[host] = 0;
        _consecutiveNetworkFailures = 0;
        
        final data = response.bodyBytes;
        
        // Store in memory cache
        _memoryCache[tileKey] = data;
        
        // Store on disk using map cache manager
        await _saveTileToMapCache(coordinates, data);
        
        return data;
      }
      else if (response.statusCode == 429 || response.statusCode >= 500) {
        // Rate limited or server error - increment error count
        _hostErrorCount[host] = (_hostErrorCount[host] ?? 0) + 1;
        
        // If we haven't tried too many times, retry after backoff
        final retryCount = _retryCount[tileKey] ?? 0;
        if (retryCount < _maxRetries) {
          _retryCount[tileKey] = retryCount + 1;
          
          // Exponential backoff
          final backoffMs = math.pow(2, retryCount) * 100;
          await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
          
          // Try again with a different subdomain if applicable
          return _loadTileFromNetwork(coordinates);
        }
        
        // Return fallback tile after max retries
        return _fallbackTile;
      }
    } catch (e) {
      // Network error
      _hostErrorCount[host] = (_hostErrorCount[host] ?? 0) + 1;
      _consecutiveNetworkFailures++;
      
      // If we've had many failures, consider going offline
      if (_consecutiveNetworkFailures > 5) {
        _isOffline = true;
        debugPrint('Network appears to be offline after multiple failures');
      }
      
      debugPrint('Network error loading tile $tileKey: $e');
      
      // Check for retry
      final retryCount = _retryCount[tileKey] ?? 0;
      if (retryCount < _maxRetries) {
        _retryCount[tileKey] = retryCount + 1;
        
        // Exponential backoff
        final backoffMs = math.pow(2, retryCount) * 200;
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
        
        // Try again with a different subdomain if applicable
        return _loadTileFromNetwork(coordinates);
      }
    }
    
    // If we get here, loading failed after retries - return fallback tile
    return _fallbackTile;
  }
  
  // Save a tile to the map cache
  Future<void> _saveTileToMapCache(TileCoordinates coordinates, Uint8List data) async {
    // Implementation will depend on the MapCacheManager API
    // This is just a placeholder
    try {
      // Get tile URL
      final url = urlTemplate
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString())
          .replaceAll('{s}', 'a'); // Use consistent subdomain for cache
      
      // Save to disk cache
      final directory = await getApplicationDocumentsDirectory();
      final tileHash = _urlToTileHash(url);
      final file = File('${directory.path}/tile_cache/$tileHash');
      
      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);
      
      // Write data to file
      await file.writeAsBytes(data);
    } catch (e) {
      debugPrint('Error saving tile to map cache: $e');
    }
  }
  
  /// Convert a tile URL to a hash for storage
  String _urlToTileHash(String url) {
    // Replace non-alphanumeric characters with underscores
    return url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '_');
  }
  
  // Load a tile into memory and disk cache via the queue system
  Future<Uint8List?> _loadTile(TileCoordinates coordinates, {bool isPriority = true}) async {
    final tileKey = _generateTileKey(coordinates);
    
    // If already in memory cache, return immediately
    if (_memoryCache.containsKey(tileKey)) {
      return _memoryCache[tileKey];
    }
    
    // If this tile is already being loaded, wait for the existing request
    if (_tilesInProgress.contains(tileKey) && _requestCompleters.containsKey(tileKey)) {
      try {
        return await _requestCompleters[tileKey]!.future;
      } catch (e) {
        // If the previous request was cancelled, start a new one
      }
    }
    
    // Queue this request
    _queueTileRequest(coordinates, isPriority: isPriority);
    
    // Wait for the result
    try {
      return await _requestCompleters[tileKey]!.future;
    } catch (e) {
      // If loading failed, return fallback tile
      debugPrint('Error loading tile $tileKey: $e');
      return _fallbackTile;
    }
  }
  
  // Clear all caches
  Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();
    
    // Clear disk cache through map cache manager
    try {
      await _mapCacheManager.clearAllCaches();
    } catch (e) {
      debugPrint('Error clearing tile cache: $e');
    }
  }
}

// Custom image provider for optimized tile loading
class OptimizedNetworkImageProvider extends ImageProvider<OptimizedNetworkImageProvider> {
  final TileCoordinates coordinates;
  final String urlTemplate;
  final Map<String, String>? headers;
  final OptimizedTileProvider tileProvider;
  final String tileKey;
  
  OptimizedNetworkImageProvider({
    required this.coordinates,
    required this.urlTemplate,
    this.headers,
    required this.tileProvider,
    required this.tileKey,
  });
  
  @override
  Future<OptimizedNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OptimizedNetworkImageProvider>(this);
  }
  
  @override
  ImageStreamCompleter loadImage(OptimizedNetworkImageProvider key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents = StreamController<ImageChunkEvent>();
    
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('Tile coordinates: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
        yield ErrorDescription('Tile URL: $urlTemplate');
      },
    );
  }
  
  Future<Codec> _loadAsync(
    OptimizedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      // Attempt to load the tile using the tile provider
      final Uint8List? bytes = await tileProvider._loadTile(coordinates);
      
      if (bytes != null) {
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: bytes.length,
          expectedTotalBytes: bytes.length,
        ));
        
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      } else {
        throw Exception('Failed to load tile');
      }
    } catch (e) {
      debugPrint('Error in tile loading: $e');
      
      // If loading failed, use fallback tile
      if (tileProvider._fallbackTile != null) {
        return decode(await ImmutableBuffer.fromUint8List(tileProvider._fallbackTile!));
      }
      
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is OptimizedNetworkImageProvider && other.tileKey == tileKey;
  }
  
  @override
  int get hashCode => tileKey.hashCode;
}

// Helper class for prioritized tile requests
class _PrioritizedTileRequest {
  final TileCoordinates coordinates;
  final int priority; // Lower number = higher priority
  
  _PrioritizedTileRequest(this.coordinates, this.priority);
}

// Helper class for queued tile requests
class _QueuedTileRequest {
  final TileCoordinates coordinates;
  final bool isPriority;
  final DateTime createdAt;
  final String tileKey;
  
  _QueuedTileRequest({
    required this.coordinates,
    required this.isPriority,
    required this.createdAt,
    required this.tileKey,
  });
} 