import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache for map data that persists across app sessions
/// Implements a multi-level cache:
/// - Memory cache (LRU) for the fastest access
/// - File system cache for all data
class PersistentMapCache {
  // Constants
  static const int _maxMemoryCacheSize = 100; // Number of items
  static const int _maxDiskCacheSizeMB = 200; // MB
  static const Duration _cacheExpiry = Duration(days: 7);
  
  // Memory cache (LRU)
  final Map<String, _CacheEntry> _memoryCache = {};
  final List<String> _lruList = [];
  
  // Metadata cache (used instead of Hive)
  Map<String, Map<String, dynamic>> _metadataCache = {};
  Map<String, String> _fileReferenceCache = {};
  
  // File system cache directory
  late final Directory _cacheDir;
  
  // Cache statistics
  int _memoryHits = 0;
  int _fileHits = 0;
  int _misses = 0;
  
  // Initialization status
  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitialized = false;
  
  /// Future that completes when the cache is initialized
  Future<void> get initialized => _initCompleter.future;
  
  /// Constructor
  PersistentMapCache() {
    _initialize();
  }
  
  /// Initialize the cache
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize cache directory
      final appDir = await getApplicationDocumentsDirectory();
      final cachePath = '${appDir.path}/map_cache';
      _cacheDir = Directory(cachePath);
      
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      
      // Load metadata from SharedPreferences
      await _loadMetadata();
      
      // Clean up expired items
      unawaited(_cleanupExpiredItems());
      
      _isInitialized = true;
      _initCompleter.complete();
      debugPrint('PersistentMapCache initialized at: ${_cacheDir.path}');
    } catch (e) {
      debugPrint('Error initializing map cache: $e');
      _initCompleter.completeError(e);
    }
  }
  
  /// Load metadata from SharedPreferences
  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load metadata cache
      final metadata = prefs.getString('map_cache_metadata');
      if (metadata != null) {
        final decoded = jsonDecode(metadata) as Map<String, dynamic>;
        _metadataCache = decoded.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value as Map)));
      }
      
      // Load file reference cache
      final fileRefs = prefs.getString('map_cache_file_refs');
      if (fileRefs != null) {
        final decoded = jsonDecode(fileRefs) as Map<String, dynamic>;
        _fileReferenceCache = decoded.map((key, value) => 
          MapEntry(key, value as String));
      }
      
      debugPrint('Loaded ${_metadataCache.length} metadata entries and ${_fileReferenceCache.length} file references');
    } catch (e) {
      debugPrint('Error loading cache metadata: $e');
      // Start with empty caches if there's an error
      _metadataCache = {};
      _fileReferenceCache = {};
    }
  }
  
  /// Save metadata to SharedPreferences
  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save metadata cache (limited to most recent entries to avoid size limits)
      final limitedMetadata = _limitMapSize(_metadataCache, 500);
      await prefs.setString('map_cache_metadata', jsonEncode(limitedMetadata));
      
      // Save file reference cache (limited to most recent entries)
      final limitedFileRefs = _limitMapSize(_fileReferenceCache, 500);
      await prefs.setString('map_cache_file_refs', jsonEncode(limitedFileRefs));
    } catch (e) {
      debugPrint('Error saving cache metadata: $e');
    }
  }
  
  /// Limit a map to a certain number of entries (most recent by LRU)
  Map<String, T> _limitMapSize<T>(Map<String, T> inputMap, int maxSize) {
    if (inputMap.length <= maxSize) return inputMap;
    
    // Use LRU list to determine which entries to keep
    final keysToKeep = _lruList.reversed.take(maxSize).toList();
    return Map.fromEntries(
      inputMap.entries.where((entry) => keysToKeep.contains(entry.key))
    );
  }
  
  /// Get a composite key for storing cache entries
  String _getCompositeKey(String dataType, String key) {
    return '$dataType:$key';
  }
  
  /// Compute a hash for a key (for filename storage)
  String _computeKeyHash(String compositeKey) {
    return md5.convert(utf8.encode(compositeKey)).toString();
  }
  
  /// Update the LRU list
  void _updateLRU(String compositeKey) {
    _lruList.remove(compositeKey);
    _lruList.add(compositeKey);
    
    // Evict if needed
    _evictIfNeeded();
  }
  
  /// Evict items if cache is too large
  void _evictIfNeeded() {
    // Memory cache eviction
    while (_lruList.length > _maxMemoryCacheSize && _lruList.isNotEmpty) {
      final keyToRemove = _lruList.removeAt(0);
      _memoryCache.remove(keyToRemove);
    }
  }
  
  /// Check if data exists in the cache
  Future<bool> hasMapData({
    required String dataType,
    required String key,
  }) async {
    await initialized;
    
    final compositeKey = _getCompositeKey(dataType, key);
    
    // Check memory cache first
    if (_memoryCache.containsKey(compositeKey)) {
      return true;
    }
    
    // Check if we have a file reference
    if (_fileReferenceCache.containsKey(compositeKey)) {
      final filePath = _fileReferenceCache[compositeKey]!;
      final file = File(filePath);
      return await file.exists();
    }
    
    // Check file cache directly
    final keyHash = _computeKeyHash(compositeKey);
    final file = File('${_cacheDir.path}/$keyHash');
    return await file.exists();
  }
  
  /// Get data from the cache
  Future<dynamic> getMapData({
    required String dataType,
    required String key,
  }) async {
    await initialized;
    
    final compositeKey = _getCompositeKey(dataType, key);
    
    // Try memory cache first (fastest)
    if (_memoryCache.containsKey(compositeKey)) {
      final entry = _memoryCache[compositeKey]!;
      
      // Check if expired
      if (entry.timestamp.add(_cacheExpiry).isBefore(DateTime.now())) {
        _memoryCache.remove(compositeKey);
        _lruList.remove(compositeKey);
        return null;
      }
      
      _memoryHits++;
      _updateLRU(compositeKey);
      return entry.data;
    }
    
    // Try file cache for this item
    try {
      // First check if we have a file reference
      String? filePath;
      if (_fileReferenceCache.containsKey(compositeKey)) {
        filePath = _fileReferenceCache[compositeKey];
      } else {
        // Try direct file lookup
        final keyHash = _computeKeyHash(compositeKey);
        filePath = '${_cacheDir.path}/$keyHash';
      }
      
      if (filePath != null) {
        final file = File(filePath);
        final metadataFile = File('$filePath.meta');
        
        if (await file.exists() && await metadataFile.exists()) {
          // Check metadata for expiry and data type
          final metadataJson = await metadataFile.readAsString();
          final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
          final timestamp = metadata['timestamp'] as String?;
          
          if (timestamp != null) {
            final cacheTime = DateTime.parse(timestamp);
            
            // Check if expired
            if (cacheTime.add(_cacheExpiry).isBefore(DateTime.now())) {
              await file.delete();
              await metadataFile.delete();
              _fileReferenceCache.remove(compositeKey);
              await _saveMetadata();
              return null;
            }
            
            // Load data based on type
            dynamic data;
            final dataType = metadata['dataType'] as String?;
            
            if (dataType == 'bytes') {
              data = await file.readAsBytes();
            } else {
              final content = await file.readAsString();
              if (dataType == 'json') {
                data = jsonDecode(content);
              } else {
                data = content;
              }
            }
            
            // Store in memory cache for future accesses
            _memoryCache[compositeKey] = _CacheEntry(
              data: data,
              timestamp: cacheTime,
            );
            _updateLRU(compositeKey);
            
            _fileHits++;
            return data;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading from file cache: $e');
    }
    
    _misses++;
    return null;
  }
  
  /// Store data in the cache
  Future<void> storeMapData({
    required String dataType,
    required String key,
    required dynamic data,
    Map<String, dynamic>? metadata,
  }) async {
    await initialized;
    
    final compositeKey = _getCompositeKey(dataType, key);
    final timestamp = DateTime.now();
    
    // Store in memory cache
    _memoryCache[compositeKey] = _CacheEntry(
      data: data,
      timestamp: timestamp,
    );
    _updateLRU(compositeKey);
    
    // Determine storage format based on data type
    String storeDataType;
    if (data is Uint8List) {
      storeDataType = 'bytes';
    } else if (data is Map || data is List) {
      storeDataType = 'json';
    } else {
      storeDataType = 'string';
    }
    
    // Store in file cache
    await _storeInFile(
      compositeKey,
      data,
      timestamp,
      dataType: storeDataType,
      metadata: metadata,
    );
  }
  
  /// Store data in file
  Future<void> _storeInFile(
    String compositeKey,
    dynamic data,
    DateTime timestamp, {
    required String dataType,
    Map<String, dynamic>? metadata,
  }) async {
    final keyHash = _computeKeyHash(compositeKey);
    final file = File('${_cacheDir.path}/$keyHash');
    final metadataFile = File('${_cacheDir.path}/$keyHash.meta');
    
    // Ensure directory exists
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    
    // Write data to file
    if (data is Uint8List) {
      await file.writeAsBytes(data);
    } else if (data is String) {
      await file.writeAsString(data);
    } else {
      await file.writeAsString(jsonEncode(data));
    }
    
    // Write metadata to file
    final metaData = {
      'timestamp': timestamp.toIso8601String(),
      'dataType': dataType,
      ...?metadata,
    };
    await metadataFile.writeAsString(jsonEncode(metaData));
    
    // Store metadata and file reference in memory
    _metadataCache[compositeKey] = metaData;
    _fileReferenceCache[compositeKey] = file.path;
    
    // Periodically save metadata (don't await to avoid blocking)
    unawaited(_saveMetadata());
  }
  
  /// Clean up expired items
  Future<void> _cleanupExpiredItems() async {
    await initialized;
    
    final now = DateTime.now();
    final expiryThreshold = now.subtract(_cacheExpiry);
    
    // Clean from memory cache
    _memoryCache.removeWhere((key, entry) {
      return entry.timestamp.isBefore(expiryThreshold);
    });
    
    // Clean file cache
    try {
      if (await _cacheDir.exists()) {
        final files = await _cacheDir.list().where((e) => !e.path.endsWith('.meta')).toList();
        
        for (final entity in files) {
          if (entity is File) {
            final metadataFile = File('${entity.path}.meta');
            
            if (await metadataFile.exists()) {
              try {
                final metadataJson = await metadataFile.readAsString();
                final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
                final timestamp = metadata['timestamp'] as String?;
                
                if (timestamp != null) {
                  final cacheTime = DateTime.parse(timestamp);
                  if (cacheTime.isBefore(expiryThreshold)) {
                    await entity.delete();
                    await metadataFile.delete();
                    
                    // Remove from reference cache if present
                    _fileReferenceCache.removeWhere((key, path) => path == entity.path);
                  }
                }
              } catch (e) {
                // Invalid metadata - delete both files
                await entity.delete();
                if (await metadataFile.exists()) {
                  await metadataFile.delete();
                }
              }
            } else {
              // No metadata - delete the file
              await entity.delete();
            }
          }
        }
        
        // Check total cache size and reduce if needed
        await _enforceMaxDiskCacheSize();
        
        // Save updated metadata
        await _saveMetadata();
      }
    } catch (e) {
      debugPrint('Error cleaning up file cache: $e');
    }
  }
  
  /// Enforce maximum disk cache size
  Future<void> _enforceMaxDiskCacheSize() async {
    try {
      final maxBytes = _maxDiskCacheSizeMB * 1024 * 1024; // Convert MB to bytes
      
      // Get all non-metadata files
      final files = await _cacheDir
          .list()
          .where((e) => !e.path.endsWith('.meta'))
          .cast<File>()
          .toList();
          
      // Calculate current size
      int totalSize = 0;
      final fileSizes = <File, int>{};
      
      for (final file in files) {
        final size = await file.length();
        fileSizes[file] = size;
        totalSize += size;
      }
      
      // If we're over the limit, delete oldest files first
      if (totalSize > maxBytes) {
        // Sort files by timestamp using metadata
        final fileInfos = <_FileInfo>[];
        
        for (final file in files) {
          final metadataFile = File('${file.path}.meta');
          
          if (await metadataFile.exists()) {
            try {
              final metadataJson = await metadataFile.readAsString();
              final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
              final timestamp = metadata['timestamp'] as String?;
              
              if (timestamp != null) {
                final cacheTime = DateTime.parse(timestamp);
                fileInfos.add(_FileInfo(
                  file: file,
                  metadataFile: metadataFile,
                  timestamp: cacheTime,
                  size: fileSizes[file] ?? 0,
                ));
              }
            } catch (e) {
              // Invalid metadata - assign old timestamp to prioritize for deletion
              fileInfos.add(_FileInfo(
                file: file,
                metadataFile: metadataFile,
                timestamp: DateTime(2000),
                size: fileSizes[file] ?? 0,
              ));
            }
          } else {
            // No metadata - assign old timestamp to prioritize for deletion
            fileInfos.add(_FileInfo(
              file: file,
              metadataFile: null,
              timestamp: DateTime(2000),
              size: fileSizes[file] ?? 0,
            ));
          }
        }
        
        // Sort by timestamp (oldest first)
        fileInfos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        // Delete until we're under the limit
        int sizeToDelete = totalSize - maxBytes;
        
        for (final fileInfo in fileInfos) {
          if (sizeToDelete <= 0) break;
          
          // Remove from reference cache
          _fileReferenceCache.removeWhere((key, path) => path == fileInfo.file.path);
          
          // Delete file
          await fileInfo.file.delete();
          if (fileInfo.metadataFile != null && await fileInfo.metadataFile!.exists()) {
            await fileInfo.metadataFile!.delete();
          }
          
          sizeToDelete -= fileInfo.size;
        }
      }
    } catch (e) {
      debugPrint('Error enforcing max disk cache size: $e');
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_items': _memoryCache.length,
      'memory_hits': _memoryHits,
      'file_refs': _fileReferenceCache.length,
      'file_hits': _fileHits,
      'misses': _misses,
      'initialized': _isInitialized,
    };
  }
  
  /// Clear all caches
  Future<void> clearAllCaches() async {
    await initialized;
    
    // Clear memory cache
    _memoryCache.clear();
    _lruList.clear();
    
    // Clear metadata
    _metadataCache.clear();
    _fileReferenceCache.clear();
    await _saveMetadata();
    
    // Clear file cache
    try {
      if (await _cacheDir.exists()) {
        final files = await _cacheDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing file cache: $e');
    }
    
    // Reset statistics
    _memoryHits = 0;
    _fileHits = 0;
    _misses = 0;
  }
  
  /// Clear cache for a specific data type
  Future<void> clearCacheForType(String dataType) async {
    await initialized;
    
    final keysToRemove = <String>[];
    final prefix = '$dataType:';
    
    // Find keys to remove from memory cache
    _memoryCache.keys.where((key) => key.startsWith(prefix)).forEach(keysToRemove.add);
    
    // Remove from memory cache
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
    
    // Remove from LRU list
    _lruList.removeWhere((key) => keysToRemove.contains(key));
    
    // Find file references to remove
    final filePathsToRemove = <String>[];
    
    _fileReferenceCache.forEach((key, path) {
      if (key.startsWith(prefix)) {
        filePathsToRemove.add(path);
      }
    });
    
    // Remove files
    for (final path in filePathsToRemove) {
      try {
        final file = File(path);
        final metadataFile = File('$path.meta');
        
        if (await file.exists()) {
          await file.delete();
        }
        
        if (await metadataFile.exists()) {
          await metadataFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting cache file: $e');
      }
    }
    
    // Remove from reference caches
    _fileReferenceCache.removeWhere((key, _) => key.startsWith(prefix));
    _metadataCache.removeWhere((key, _) => key.startsWith(prefix));
    
    // Save updated metadata
    await _saveMetadata();
  }
}

/// Class to store cache entry in memory
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  
  _CacheEntry({
    required this.data,
    required this.timestamp,
  });
}

/// Class to track file info for cache cleanup
class _FileInfo {
  final File file;
  final File? metadataFile;
  final DateTime timestamp;
  final int size;
  
  _FileInfo({
    required this.file,
    required this.metadataFile,
    required this.timestamp,
    required this.size,
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