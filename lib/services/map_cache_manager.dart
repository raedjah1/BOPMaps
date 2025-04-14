import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hyperbolic sine implementation - not available directly in dart:math
double _sinh(double x) {
  return (math.exp(x) - math.exp(-x)) / 2;
}

/// A class for managing offline map regions, including downloading, storing, and retrieving tiles
class MapCacheManager {
  static final MapCacheManager _instance = MapCacheManager._internal();
  
  /// Singleton instance of MapCacheManager
  factory MapCacheManager() => _instance;
  
  MapCacheManager._internal();
  
  /// Base directory for storing map tiles
  Directory? _cacheDir;
  
  /// Map of currently downloading regions (regionId -> download progress)
  final Map<String, double> _downloadProgress = {};
  
  /// Stream controller for download progress updates
  final _downloadProgressController = StreamController<MapDownloadProgress>.broadcast();
  
  /// Stream of download progress updates
  Stream<MapDownloadProgress> get downloadProgressStream => _downloadProgressController.stream;
  
  /// Initializes the cache manager
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/map_cache');
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // Create the regions directory if it doesn't exist
      final regionsDir = Directory('${_cacheDir!.path}/regions');
      if (!await regionsDir.exists()) {
        await regionsDir.create(recursive: true);
      }
      
      debugPrint('MapCacheManager initialized at: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('Error initializing MapCacheManager: $e');
      rethrow;
    }
  }
  
  /// Get the list of saved offline regions
  Future<List<OfflineRegion>> getOfflineRegions() async {
    try {
      await _ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      final regionsJson = prefs.getStringList('offline_regions') ?? [];
      
      return regionsJson
          .map((json) => OfflineRegion.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('Error getting offline regions: $e');
      return [];
    }
  }
  
  /// Save a new offline region metadata
  Future<bool> saveRegionMetadata(OfflineRegion region) async {
    try {
      await _ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      final regionsJson = prefs.getStringList('offline_regions') ?? [];
      
      // Check if region with the same ID already exists
      final existingIndex = regionsJson.indexWhere((json) {
        final existingRegion = OfflineRegion.fromJson(jsonDecode(json));
        return existingRegion.id == region.id;
      });
      
      if (existingIndex >= 0) {
        regionsJson[existingIndex] = jsonEncode(region.toJson());
      } else {
        regionsJson.add(jsonEncode(region.toJson()));
      }
      
      await prefs.setStringList('offline_regions', regionsJson);
      return true;
    } catch (e) {
      debugPrint('Error saving region metadata: $e');
      return false;
    }
  }
  
  /// Remove an offline region
  Future<bool> removeOfflineRegion(String regionId) async {
    try {
      await _ensureInitialized();
      
      // Remove metadata
      final prefs = await SharedPreferences.getInstance();
      final regionsJson = prefs.getStringList('offline_regions') ?? [];
      
      final filteredRegions = regionsJson.where((json) {
        final region = OfflineRegion.fromJson(jsonDecode(json));
        return region.id != regionId;
      }).toList();
      
      await prefs.setStringList('offline_regions', filteredRegions);
      
      // Remove tiles directory
      final regionDir = Directory('${_cacheDir!.path}/regions/$regionId');
      if (await regionDir.exists()) {
        await regionDir.delete(recursive: true);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error removing offline region: $e');
      return false;
    }
  }
  
  /// Check if a tile is available in the cache
  Future<bool> isTileCached(TileCoordinates coords, TileLayer options) async {
    await _ensureInitialized();
    
    final tileUrl = _getTileUrl(coords, options);
    final tileHash = _urlToTileHash(tileUrl);
    
    final tileFile = File('${_cacheDir!.path}/tiles/$tileHash');
    return tileFile.exists();
  }
  
  /// Get a cached tile as bytes
  Future<Uint8List?> getCachedTile(TileCoordinates coords, TileLayer options) async {
    await _ensureInitialized();
    
    final tileUrl = _getTileUrl(coords, options);
    final tileHash = _urlToTileHash(tileUrl);
    
    // First check memory cache for faster access
    if (_memoryTileCache.containsKey(tileHash)) {
      return _memoryTileCache[tileHash];
    }
    
    // Then check disk cache
    final tileFile = File('${_cacheDir!.path}/tiles/$tileHash');
    if (await tileFile.exists()) {
      try {
        final data = await tileFile.readAsBytes();
        // Store in memory cache for next time
        _memoryTileCache[tileHash] = data;
        return data;
      } catch (e) {
        debugPrint('Error reading cached tile: $e');
        // If reading fails, we'll try to download below
      }
    }
    
    // Next, check offline regions - they might contain this tile
    for (final region in await getOfflineRegions()) {
      if (region.status == OfflineRegionStatus.downloaded && 
          _isTileInRegion(coords, region)) {
        final regionTileFile = File('${_cacheDir!.path}/regions/${region.id}/$tileHash');
        if (await regionTileFile.exists()) {
          try {
            final data = await regionTileFile.readAsBytes();
            // Store in memory cache for next time
            _memoryTileCache[tileHash] = data;
            return data;
          } catch (e) {
            debugPrint('Error reading offline region tile: $e');
            // If reading fails, we'll try to download below
          }
        }
      }
    }
    
    // If we couldn't find it in any cache, return null (caller should download)
    return null;
  }
  
  /// Download an offline region
  Future<bool> downloadRegion(OfflineRegion region, {
    void Function(double progress)? onProgress,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) async {
    try {
      await _ensureInitialized();
      
      // Check if download already in progress
      if (_downloadProgress.containsKey(region.id)) {
        onError?.call('Download already in progress for this region');
        return false;
      }
      
      _downloadProgress[region.id] = 0.0;
      _notifyDownloadProgress(region.id, 0.0);
      
      // Create the region directory
      final regionDir = Directory('${_cacheDir!.path}/regions/${region.id}');
      if (!await regionDir.exists()) {
        await regionDir.create(recursive: true);
      }
      
      // Save the region metadata with downloading status
      final updatedRegion = region.copyWith(
        downloadedAt: null,
        status: OfflineRegionStatus.downloading,
      );
      await saveRegionMetadata(updatedRegion);
      
      // Calculate total tiles to download
      final bounds = LatLngBounds(
        LatLng(region.south, region.west),
        LatLng(region.north, region.east),
      );
      
      final tileUrls = <String>[];
      
      // Generate tile URLs for all zoom levels
      for (int zoom = region.minZoom; zoom <= region.maxZoom; zoom++) {
        final tileRange = _getTileRange(bounds, zoom);
        
        for (int x = tileRange.min.x; x <= tileRange.max.x; x++) {
          for (int y = tileRange.min.y; y <= tileRange.max.y; y++) {
            final coords = TileCoordinates(x: x, y: y, z: zoom);
            final url = 'https://tile.openstreetmap.org/${coords.z}/${coords.x}/${coords.y}.png';
            tileUrls.add(url);
          }
        }
      }
      
      final totalTiles = tileUrls.length;
      int downloadedTiles = 0;
      
      // Create a queue of URLs to download
      final futures = <Future>[];
      final maxConcurrent = 5; // Limit concurrent downloads to avoid rate limiting
      
      for (final url in tileUrls) {
        if (futures.length >= maxConcurrent) {
          // Wait for one download to complete before starting another
          await futures.removeAt(0);
        }
        
        final future = _downloadTile(url, regionDir).then((_) {
          downloadedTiles++;
          
          final progress = downloadedTiles / totalTiles;
          _downloadProgress[region.id] = progress;
          
          onProgress?.call(progress);
          _notifyDownloadProgress(region.id, progress);
        });
        
        futures.add(future);
        
        // Add a small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Wait for all downloads to complete
      await Future.wait(futures);
      
      // Update region metadata
      final completedRegion = updatedRegion.copyWith(
        downloadedAt: DateTime.now(),
        status: OfflineRegionStatus.downloaded,
        totalTiles: totalTiles,
      );
      await saveRegionMetadata(completedRegion);
      
      _downloadProgress.remove(region.id);
      _notifyDownloadProgress(region.id, 1.0, isComplete: true);
      
      onComplete?.call();
      return true;
    } catch (e) {
      debugPrint('Error downloading region: $e');
      
      _downloadProgress.remove(region.id);
      
      // Update region metadata with error status
      final failedRegion = region.copyWith(
        status: OfflineRegionStatus.error,
        error: e.toString(),
      );
      await saveRegionMetadata(failedRegion);
      
      onError?.call(e.toString());
      _notifyDownloadProgress(region.id, 0.0, error: e.toString());
      
      return false;
    }
  }
  
  /// Cancel a region download
  Future<bool> cancelDownload(String regionId) async {
    if (!_downloadProgress.containsKey(regionId)) {
      return false;
    }
    
    // Update region metadata
    final regions = await getOfflineRegions();
    final region = regions.firstWhere(
      (r) => r.id == regionId,
      orElse: () => throw Exception('Region not found'),
    );
    
    final cancelledRegion = region.copyWith(
      status: OfflineRegionStatus.cancelled,
    );
    await saveRegionMetadata(cancelledRegion);
    
    _downloadProgress.remove(regionId);
    _notifyDownloadProgress(regionId, 0.0, isCancelled: true);
    
    return true;
  }
  
  /// Get the current download progress for a region
  double getDownloadProgress(String regionId) {
    return _downloadProgress[regionId] ?? 0.0;
  }
  
  /// Ensure the cache manager is initialized
  Future<void> _ensureInitialized() async {
    if (_cacheDir == null) {
      await initialize();
    }
  }
  
  /// Download a single tile
  Future<void> _downloadTile(String url, Directory regionDir) async {
    try {
      final tileHash = _urlToTileHash(url);
      final tileFile = File('${regionDir.path}/$tileHash');
      
      // Skip if the tile already exists
      if (await tileFile.exists()) {
        return;
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await tileFile.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to download tile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading tile $url: $e');
      rethrow;
    }
  }
  
  /// Convert a tile URL to a hash for storage
  String _urlToTileHash(String url) {
    // Replace non-alphanumeric characters with underscores
    return url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '_');
  }
  
  /// Get the URL for a tile
  String _getTileUrl(TileCoordinates coords, TileLayer options) {
    final url = options.urlTemplate!
        .replaceAll('{z}', coords.z.toString())
        .replaceAll('{x}', coords.x.toString())
        .replaceAll('{y}', coords.y.toString());
        
    return url;
  }
  
  /// Get the range of tiles for a bounding box
  _TileRange _getTileRange(LatLngBounds bounds, int zoom) {
    final min = _latLngToTilePoint(bounds.southWest, zoom);
    final max = _latLngToTilePoint(bounds.northEast, zoom);
    
    return _TileRange(min, max);
  }
  
  /// Convert LatLng to tile coordinates
  _TilePoint _latLngToTilePoint(LatLng latlng, int zoom) {
    const earthRadius = 6378137.0;
    const initialResolution = 2 * math.pi * earthRadius / 256;
    const originShift = 2 * math.pi * earthRadius / 2;
    
    final resolution = initialResolution / (1 << zoom);
    
    final x = (latlng.longitude + 180) / 360 * (1 << zoom);
    final sinLatitude = math.sin(latlng.latitude * math.pi / 180);
    final y = (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) * (1 << zoom);
    
    return _TilePoint(x.floor(), y.floor());
  }
  
  /// Notify listeners of download progress updates
  void _notifyDownloadProgress(String regionId, double progress, {
    bool isComplete = false,
    bool isCancelled = false,
    String? error,
  }) {
    _downloadProgressController.add(
      MapDownloadProgress(
        regionId: regionId,
        progress: progress,
        isComplete: isComplete,
        isCancelled: isCancelled,
        error: error,
      ),
    );
  }
  
  /// Clean up resources
  void dispose() {
    _downloadProgressController.close();
  }
  
  // Add a memory cache to avoid repeated disk reads
  final Map<String, Uint8List> _memoryTileCache = {};
  
  // Check if a tile is within a region's bounds
  bool _isTileInRegion(TileCoordinates coords, OfflineRegion region) {
    // Skip if the zoom level is outside the region's zoom range
    if (coords.z < region.minZoom || coords.z > region.maxZoom) {
      return false;
    }
    
    // Convert tile coordinates to lat/lng
    final LatLng tileLatLng = _tileToLatLng(coords);
    
    // Check if the tile is within the region bounds
    return tileLatLng.latitude <= region.north &&
           tileLatLng.latitude >= region.south &&
           tileLatLng.longitude <= region.east &&
           tileLatLng.longitude >= region.west;
  }
  
  // Convert tile coordinates to approximate center LatLng
  LatLng _tileToLatLng(TileCoordinates coords) {
    final n = math.pow(2.0, coords.z.toDouble());
    final lonDeg = coords.x / n * 360.0 - 180.0;
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * coords.y / n)));
    final latDeg = latRad * 180.0 / math.pi;
    return LatLng(latDeg, lonDeg);
  }
  
  /// Get fallback tile when everything else fails
  Future<Uint8List?> getFallbackTile() async {
    await _ensureInitialized();
    
    final fallbackTileFile = File('${_cacheDir!.path}/fallback_tile.png');
    
    // If fallback already exists, return it
    if (await fallbackTileFile.exists()) {
      return fallbackTileFile.readAsBytes();
    }
    
    // Otherwise create a simple fallback tile
    try {
      // Create a blank tile with grid lines
      final data = await _createFallbackTile();
      
      // Save it for future use
      await fallbackTileFile.writeAsBytes(data);
      
      return data;
    } catch (e) {
      debugPrint('Error creating fallback tile: $e');
      // Return a simple gray tile as last resort
      return Uint8List.fromList(List.filled(256 * 256 * 4, 200));
    }
  }
  
  // Create a simple fallback tile
  Future<Uint8List> _createFallbackTile() async {
    // Implementation will depend on whether we have access to Flutter's
    // drawing APIs from this non-UI class. This is a placeholder.
    // Create a simple gray tile with a grid pattern
    // Size: 256x256 pixels (standard tile size)
    final byteData = ByteData(256 * 256 * 4); // RGBA
    
    // Fill with light gray
    for (int i = 0; i < 256 * 256; i++) {
      final offset = i * 4;
      byteData.setUint8(offset, 240);     // R
      byteData.setUint8(offset + 1, 240); // G
      byteData.setUint8(offset + 2, 240); // B
      byteData.setUint8(offset + 3, 255); // A (opaque)
    }
    
    // Add grid lines
    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        // Draw grid lines every 32 pixels
        if (x % 32 == 0 || y % 32 == 0) {
          final offset = (y * 256 + x) * 4;
          byteData.setUint8(offset, 200);     // R
          byteData.setUint8(offset + 1, 200); // G
          byteData.setUint8(offset + 2, 200); // B
          byteData.setUint8(offset + 3, 255); // A
        }
      }
    }
    
    return byteData.buffer.asUint8List();
  }
  
  /// Clean up memory cache
  void cleanMemoryCache({int maxItems = 200}) {
    // If cache is smaller than limit, do nothing
    if (_memoryTileCache.length <= maxItems) return;
    
    // Remove oldest items (we don't track age, so remove first N)
    final keysToRemove = _memoryTileCache.keys.take(_memoryTileCache.length - maxItems);
    for (final key in keysToRemove) {
      _memoryTileCache.remove(key);
    }
  }
}

/// Class for tile coordinates
class TileCoordinates {
  final int x;
  final int y;
  final int z;
  
  TileCoordinates({required this.x, required this.y, required this.z});
}

/// Represents an offline map region
class OfflineRegion {
  final String id;
  final String name;
  final double north;
  final double south;
  final double east;
  final double west;
  final int minZoom;
  final int maxZoom;
  final DateTime? createdAt;
  final DateTime? downloadedAt;
  final OfflineRegionStatus status;
  final int? totalTiles;
  final int? downloadedTiles;
  final String? error;
  
  const OfflineRegion({
    required this.id,
    required this.name,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.minZoom,
    required this.maxZoom,
    this.createdAt,
    this.downloadedAt,
    this.status = OfflineRegionStatus.pending,
    this.totalTiles,
    this.downloadedTiles,
    this.error,
  });
  
  /// Calculate the area of the region in square kilometers
  double get areaKm2 {
    // Approximate radius of Earth in kilometers
    const earthRadius = 6371.0;
    
    // Convert to radians
    final northRad = north * math.pi / 180;
    final southRad = south * math.pi / 180;
    final eastRad = east * math.pi / 180;
    final westRad = west * math.pi / 180;
    
    // Calculate width and height
    final width = earthRadius * math.cos((northRad + southRad) / 2) * (eastRad - westRad);
    final height = earthRadius * (northRad - southRad);
    
    return width.abs() * height.abs();
  }
  
  /// Create a copy of this region with optional new values
  OfflineRegion copyWith({
    String? name,
    double? north,
    double? south,
    double? east,
    double? west,
    int? minZoom,
    int? maxZoom,
    DateTime? createdAt,
    DateTime? downloadedAt,
    OfflineRegionStatus? status,
    int? totalTiles,
    int? downloadedTiles,
    String? error,
  }) {
    return OfflineRegion(
      id: id,
      name: name ?? this.name,
      north: north ?? this.north,
      south: south ?? this.south,
      east: east ?? this.east,
      west: west ?? this.west,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      createdAt: createdAt ?? this.createdAt,
      downloadedAt: downloadedAt,
      status: status ?? this.status,
      totalTiles: totalTiles ?? this.totalTiles,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      error: error ?? this.error,
    );
  }
  
  /// Create a region from JSON
  factory OfflineRegion.fromJson(Map<String, dynamic> json) {
    return OfflineRegion(
      id: json['id'] as String,
      name: json['name'] as String,
      north: (json['north'] as num).toDouble(),
      south: (json['south'] as num).toDouble(),
      east: (json['east'] as num).toDouble(),
      west: (json['west'] as num).toDouble(),
      minZoom: json['minZoom'] as int,
      maxZoom: json['maxZoom'] as int,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'] as String)
          : null,
      status: _parseStatus(json['status'] as String?),
      totalTiles: json['totalTiles'] as int?,
      downloadedTiles: json['downloadedTiles'] as int?,
      error: json['error'] as String?,
    );
  }
  
  /// Convert this region to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'north': north,
      'south': south,
      'east': east,
      'west': west,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'createdAt': createdAt?.toIso8601String(),
      'downloadedAt': downloadedAt?.toIso8601String(),
      'status': status.toString().split('.').last,
      'totalTiles': totalTiles,
      'downloadedTiles': downloadedTiles,
      'error': error,
    };
  }
  
  /// Parse the status from a string
  static OfflineRegionStatus _parseStatus(String? status) {
    if (status == null) return OfflineRegionStatus.pending;
    
    switch (status) {
      case 'pending': return OfflineRegionStatus.pending;
      case 'downloading': return OfflineRegionStatus.downloading;
      case 'downloaded': return OfflineRegionStatus.downloaded;
      case 'cancelled': return OfflineRegionStatus.cancelled;
      case 'error': return OfflineRegionStatus.error;
      default: return OfflineRegionStatus.pending;
    }
  }
}

/// Status of an offline region
enum OfflineRegionStatus {
  pending,
  downloading,
  downloaded,
  cancelled,
  error,
}

/// Class to represent download progress updates
class MapDownloadProgress {
  final String regionId;
  final double progress;
  final bool isComplete;
  final bool isCancelled;
  final String? error;
  
  const MapDownloadProgress({
    required this.regionId,
    required this.progress,
    this.isComplete = false,
    this.isCancelled = false,
    this.error,
  });
}

/// Helper class for tile ranges
class _TileRange {
  final _TilePoint min;
  final _TilePoint max;
  
  const _TileRange(this.min, this.max);
}

/// Helper class for tile coordinates
class _TilePoint {
  final int x;
  final int y;
  
  const _TilePoint(this.x, this.y);
} 