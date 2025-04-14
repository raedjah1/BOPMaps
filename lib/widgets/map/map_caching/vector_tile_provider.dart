import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/map_cache_manager.dart';
import 'optimized_tile_provider.dart';

/// A sophisticated provider for vector tiles that handles fetching, caching,
/// and rendering of vector map data for high-performance maps.
class VectorTileProvider extends TileProvider {
  // Vector tile providers
  static const String _osmVectorUrl = 'https://tiles.stadiamaps.com/data/openmaptiles/{z}/{x}/{y}.pbf';
  static const String _mapTilerUrl = 'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key={key}';
  
  // Vector tile styling
  static const String _styleUrl = 'https://api.maptiler.com/maps/streets/style.json?key={key}';
  
  // Default API key - should be replaced with your own
  static const String _defaultApiKey = 'get_your_key_from_maptiler';
  
  // Cache settings
  static const int _maxDiskCacheSize = 200 * 1024 * 1024; // 200 MB
  static const int _maxMemoryCacheSize = 50 * 1024 * 1024; // 50 MB
  
  // Memory cache for decoded vector tiles
  final Map<String, VectorTile> _memoryCache = {};
  
  // Disk cache path
  String? _diskCachePath;
  
  // API key for commercial tile providers
  final String apiKey;
  
  // Vector tile style
  Map<String, dynamic>? _style;
  
  // Map style mode
  final String styleMode;
  
  // Throttling parameters
  int _requestsInLastMinute = 0;
  DateTime _lastRequestCounter = DateTime.now();
  static const int _maxRequestsPerMinute = 300;
  
  // Backend service - option to use a proxy server for tiles
  final bool useProxy;
  final String? proxyUrl;
  
  // Isolate pool for parallel processing
  List<Isolate>? _isolatePool;
  List<SendPort>? _sendPorts;
  
  VectorTileProvider({
    this.apiKey = _defaultApiKey,
    this.styleMode = 'streets',
    this.useProxy = false,
    this.proxyUrl,
  }) {
    _initCache();
    _loadStyle();
    _initIsolatePool();
  }
  
  /// Initialize the cache directories
  Future<void> _initCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _diskCachePath = '${appDir.path}/vector_tile_cache';
      
      final cacheDir = Directory(_diskCachePath!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      // Clean old files if cache is too large
      _cleanCacheIfNeeded();
    } catch (e) {
      debugPrint('Error initializing vector tile cache: $e');
    }
  }
  
  /// Load the map style definition
  Future<void> _loadStyle() async {
    try {
      final styleUrlWithKey = _styleUrl.replaceAll('{key}', apiKey);
      final response = await http.get(Uri.parse(styleUrlWithKey));
      
      if (response.statusCode == 200) {
        _style = jsonDecode(response.body);
        debugPrint('Loaded vector tile style with ${_style?['layers']?.length ?? 0} layers');
      } else {
        debugPrint('Failed to load vector tile style: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading vector tile style: $e');
    }
  }
  
  /// Initialize a pool of isolates for tile processing
  Future<void> _initIsolatePool() async {
    final int numIsolates = Platform.numberOfProcessors - 1;
    _isolatePool = [];
    _sendPorts = [];
    
    for (int i = 0; i < numIsolates; i++) {
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn<SendPort>(
        _vectorTileProcessingIsolate,
        receivePort.sendPort,
      );
      
      _isolatePool!.add(isolate);
      
      // Get the send port from the isolate
      final sendPort = await receivePort.first as SendPort;
      _sendPorts!.add(sendPort);
    }
    
    debugPrint('Initialized vector tile processing pool with $numIsolates isolates');
  }
  
  /// The entry point for the tile processing isolate
  static void _vectorTileProcessingIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        final responsePort = message['responsePort'] as SendPort;
        final tileData = message['tileData'] as Uint8List;
        final z = message['z'] as int;
        final x = message['x'] as int;
        final y = message['y'] as int;
        
        try {
          // Process the vector tile data
          final processedTile = _processVectorTile(tileData, z, x, y);
          responsePort.send({
            'success': true,
            'tile': processedTile,
          });
        } catch (e) {
          responsePort.send({
            'success': false,
            'error': e.toString(),
          });
        }
      }
    });
  }
  
  /// Process vector tile data in the isolate
  static Map<String, dynamic> _processVectorTile(Uint8List tileData, int z, int x, int y) {
    // This is a simplified example - in a real implementation you'd use a 
    // proper vector tile parser library to decode the protobuf format
    
    // Decode the PBF (Protocol Buffer) data
    // Here we'd use a library like 'vector_tile' to decode the actual data
    
    // For this example, we'll just return a mock processed tile
    return {
      'layers': [
        {
          'name': 'buildings',
          'features': [
            // Feature data would go here
          ],
        },
        {
          'name': 'roads',
          'features': [
            // Feature data would go here
          ],
        },
      ],
    };
  }
  
  /// Get a tile image for the specified coordinates
  @override
  Future<TileImage> getTileImage(TileCoordinates coordinates, TileLayer options) async {
    final String tileKey = 'vector_${coordinates.z}_${coordinates.x}_${coordinates.y}';
    
    // Check memory cache first
    if (_memoryCache.containsKey(tileKey)) {
      return ImageTileImage(_memoryCache[tileKey]!.image);
    }
    
    // Then check disk cache
    final cachedTile = await _loadTileFromDiskCache(tileKey);
    if (cachedTile != null) {
      _memoryCache[tileKey] = cachedTile;
      return ImageTileImage(cachedTile.image);
    }
    
    // If not cached, fetch from network with throttling
    await _throttleRequests();
    
    try {
      // Construct the appropriate URL for the vector tile
      String url = _osmVectorUrl
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString());
          
      if (useProxy && proxyUrl != null) {
        // Use proxy if configured
        url = '$proxyUrl?url=${Uri.encodeComponent(url)}';
      }
      
      // Fetch the tile data
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Vector tile request timed out'),
      );
      
      if (response.statusCode == 200) {
        // Process the tile data in an isolate
        final vectorTile = await _processVectorTileData(
          response.bodyBytes, 
          coordinates.z, 
          coordinates.x, 
          coordinates.y
        );
        
        // Cache the processed tile
        _memoryCache[tileKey] = vectorTile;
        _saveTileToDiskCache(tileKey, vectorTile);
        
        return ImageTileImage(vectorTile.image);
      } else {
        debugPrint('Error fetching vector tile: ${response.statusCode}');
        throw Exception('Failed to load vector tile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading vector tile: $e');
      // Return a placeholder for failed tiles
      return const ColoredTileImage(Colors.grey);
    }
  }
  
  /// Process vector tile data using the isolate pool
  Future<VectorTile> _processVectorTileData(Uint8List tileData, int z, int x, int y) async {
    if (_sendPorts == null || _sendPorts!.isEmpty) {
      // Fallback if isolate pool isn't initialized
      return _processVectorTileInMainThread(tileData, z, x, y);
    }
    
    // Select an isolate round-robin
    final int isolateIndex = (x + y) % _sendPorts!.length;
    final sendPort = _sendPorts![isolateIndex];
    
    // Create a port for receiving the processed result
    final responsePort = ReceivePort();
    
    // Send the data to the isolate
    sendPort.send({
      'responsePort': responsePort.sendPort,
      'tileData': tileData,
      'z': z,
      'x': x,
      'y': y,
    });
    
    // Wait for the result
    final result = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    
    if (result['success'] == true) {
      // Convert the processed data to a VectorTile
      return _renderVectorTile(result['tile'], z, x, y);
    } else {
      throw Exception('Error processing vector tile: ${result['error']}');
    }
  }
  
  /// Fallback method to process vector tile in the main thread if isolates aren't available
  Future<VectorTile> _processVectorTileInMainThread(Uint8List tileData, int z, int x, int y) async {
    // Process the tile data directly
    final processedData = _processVectorTile(tileData, z, x, y);
    return _renderVectorTile(processedData, z, x, y);
  }
  
  /// Render the vector tile data to an image
  Future<VectorTile> _renderVectorTile(Map<String, dynamic> tileData, int z, int x, int y) async {
    // Create a picture recorder to draw the tile
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = const Size(256.0, 256.0); // Standard tile size
    
    // Clear background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = styleMode == 'dark' ? const Color(0xFF1A1A1A) : Colors.white,
    );
    
    // Render each layer based on the style
    if (_style != null && _style!['layers'] is List) {
      final layers = _style!['layers'] as List;
      
      // Process layers in order defined by the style
      for (final layer in layers) {
        final layerName = layer['id'];
        final sourceLayer = layer['source-layer'];
        
        // Find matching layer in tile data
        final tileLayer = (tileData['layers'] as List?)?.firstWhere(
          (l) => l['name'] == sourceLayer,
          orElse: () => null,
        );
        
        if (tileLayer != null) {
          _renderLayer(canvas, size, tileLayer, layer);
        }
      }
    } else {
      // Fallback rendering if no style is available
      _renderFallbackTile(canvas, size, tileData);
    }
    
    // End the recording and get the picture
    final picture = pictureRecorder.endRecording();
    
    // Convert to an image
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    
    // Create a byte representation (for caching)
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
    
    // Create and return a VectorTile object
    return VectorTile(
      tileData: tileData,
      image: image,
      pngBytes: pngBytes,
      z: z,
      x: x,
      y: y,
    );
  }
  
  /// Render a specific layer based on the style
  void _renderLayer(Canvas canvas, Size size, Map<String, dynamic> tileLayer, Map<String, dynamic> styleLayer) {
    final layerType = styleLayer['type'];
    final paint = Paint();
    
    // Apply style properties
    if (styleLayer['paint'] is Map) {
      final paintProps = styleLayer['paint'] as Map;
      
      // Set color
      if (paintProps['fill-color'] is String) {
        paint.color = _parseColor(paintProps['fill-color']);
      }
      
      // Set stroke width
      if (paintProps['line-width'] is num) {
        paint.strokeWidth = (paintProps['line-width'] as num).toDouble();
      }
      
      // Set style
      if (layerType == 'fill') {
        paint.style = PaintingStyle.fill;
      } else if (layerType == 'line') {
        paint.style = PaintingStyle.stroke;
      }
    }
    
    // Draw features
    if (tileLayer['features'] is List) {
      for (final feature in tileLayer['features']) {
        if (layerType == 'fill' || layerType == 'line') {
          _drawGeometry(canvas, feature['geometry'], paint);
        } else if (layerType == 'symbol') {
          _drawSymbol(canvas, feature, styleLayer);
        }
      }
    }
  }
  
  /// Draw geometry (polygons or lines)
  void _drawGeometry(Canvas canvas, Map<String, dynamic> geometry, Paint paint) {
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    
    if (type == 'Polygon' && coordinates is List) {
      for (final ring in coordinates) {
        if (ring is List && ring.length > 2) {
          final path = Path();
          bool first = true;
          
          for (final coord in ring) {
            if (coord is List && coord.length >= 2) {
              final x = (coord[0] as num).toDouble();
              final y = (coord[1] as num).toDouble();
              
              if (first) {
                path.moveTo(x, y);
                first = false;
              } else {
                path.lineTo(x, y);
              }
            }
          }
          
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    } else if (type == 'LineString' && coordinates is List) {
      final path = Path();
      bool first = true;
      
      for (final coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          final x = (coord[0] as num).toDouble();
          final y = (coord[1] as num).toDouble();
          
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  /// Draw symbols (icons or text)
  void _drawSymbol(Canvas canvas, Map<String, dynamic> feature, Map<String, dynamic> styleLayer) {
    // Simplified implementation - in a real implementation you'd handle sprites
    // and text placement based on the style
    
    // For this example, just draw a small dot
    final geometry = feature['geometry'];
    if (geometry['type'] == 'Point' && geometry['coordinates'] is List) {
      final coord = geometry['coordinates'];
      if (coord.length >= 2) {
        final x = (coord[0] as num).toDouble();
        final y = (coord[1] as num).toDouble();
        
        canvas.drawCircle(
          Offset(x, y),
          2.0,
          Paint()..color = Colors.black,
        );
      }
    }
  }
  
  /// Fallback rendering for when no style is available
  void _renderFallbackTile(Canvas canvas, Size size, Map<String, dynamic> tileData) {
    // Draw a grid to show the tile is loaded
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final pos = i * (size.width / 4);
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), paint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), paint);
    }
    
    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Vector Tile',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }
  
  /// Parse color string from style
  Color _parseColor(String colorStr) {
    // Handle named colors
    if (colorStr == 'white') return Colors.white;
    if (colorStr == 'black') return Colors.black;
    
    // Handle hex colors
    if (colorStr.startsWith('#')) {
      final value = int.tryParse(colorStr.substring(1), radix: 16);
      if (value != null) {
        if (colorStr.length == 7) {
          // #RRGGBB format
          return Color(0xFF000000 | value);
        } else if (colorStr.length == 9) {
          // #AARRGGBB format
          return Color(value);
        }
      }
    }
    
    // Handle rgba format
    if (colorStr.startsWith('rgba(')) {
      final values = colorStr
          .substring(5, colorStr.length - 1)
          .split(',')
          .map((s) => double.tryParse(s.trim()))
          .toList();
      
      if (values.length == 4 && !values.contains(null)) {
        return Color.fromRGBO(
          values[0]!.toInt(),
          values[1]!.toInt(),
          values[2]!.toInt(),
          values[3]!,
        );
      }
    }
    
    // Default color
    return Colors.grey;
  }
  
  /// Load a tile from disk cache
  Future<VectorTile?> _loadTileFromDiskCache(String tileKey) async {
    if (_diskCachePath == null) return null;
    
    try {
      final file = File('$_diskCachePath/$tileKey.bin');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        // First 8 bytes are header (version, format)
        // Next 4 bytes are the length of the JSON data
        if (bytes.length < 12) return null;
        
        final jsonLength = _bytesToInt(bytes.sublist(8, 12));
        if (bytes.length < 12 + jsonLength) return null;
        
        // Extract the JSON data
        final jsonBytes = bytes.sublist(12, 12 + jsonLength);
        final jsonString = utf8.decode(jsonBytes);
        final tileData = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Extract the PNG image data
        final pngBytes = bytes.sublist(12 + jsonLength);
        
        // Decode the PNG image
        final codec = await ui.instantiateImageCodec(pngBytes);
        final frameInfo = await codec.getNextFrame();
        
        // Create a VectorTile object
        return VectorTile(
          tileData: tileData,
          image: frameInfo.image,
          pngBytes: pngBytes,
          z: tileData['z'] as int,
          x: tileData['x'] as int,
          y: tileData['y'] as int,
        );
      }
    } catch (e) {
      debugPrint('Error loading vector tile from disk cache: $e');
    }
    
    return null;
  }
  
  /// Save a tile to disk cache
  Future<void> _saveTileToDiskCache(String tileKey, VectorTile tile) async {
    if (_diskCachePath == null) return;
    
    try {
      final file = File('$_diskCachePath/$tileKey.bin');
      
      // Convert the tile data to JSON
      final jsonString = jsonEncode({
        ...tile.tileData,
        'z': tile.z,
        'x': tile.x,
        'y': tile.y,
      });
      
      final jsonBytes = utf8.encode(jsonString);
      
      // Create a binary file format:
      // - 4 bytes: format version (1)
      // - 4 bytes: format type (1 = vector)
      // - 4 bytes: JSON data length
      // - N bytes: JSON data
      // - M bytes: PNG image data
      
      final outputBytes = BytesBuilder();
      outputBytes.add(_intToBytes(1)); // Version 1
      outputBytes.add(_intToBytes(1)); // Type 1 (vector)
      outputBytes.add(_intToBytes(jsonBytes.length));
      outputBytes.add(jsonBytes);
      outputBytes.add(tile.pngBytes);
      
      await file.writeAsBytes(outputBytes.toBytes());
    } catch (e) {
      debugPrint('Error saving vector tile to disk cache: $e');
    }
  }
  
  /// Clean the cache if it's too large
  Future<void> _cleanCacheIfNeeded() async {
    if (_diskCachePath == null) return;
    
    try {
      final cacheDir = Directory(_diskCachePath!);
      final files = await cacheDir.list().toList();
      
      // Calculate total size
      int totalSize = 0;
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      // If cache is too large, delete oldest files
      if (totalSize > _maxDiskCacheSize) {
        // Sort files by modification time (oldest first)
        files.sort((a, b) async {
          final statA = await (a as File).stat();
          final statB = await (b as File).stat();
          return statA.modified.compareTo(statB.modified);
        });
        
        // Delete oldest files until we're under the limit
        int deletedSize = 0;
        for (final entity in files) {
          if (totalSize - deletedSize <= _maxDiskCacheSize * 0.8) {
            break; // Stop when we've reduced to 80% of max
          }
          
          if (entity is File) {
            final stat = await entity.stat();
            deletedSize += stat.size;
            await entity.delete();
          }
        }
        
        debugPrint('Cleaned vector tile cache: ${deletedSize ~/ 1024} KB removed');
      }
    } catch (e) {
      debugPrint('Error cleaning vector tile cache: $e');
    }
  }
  
  /// Throttle requests to avoid hitting API limits
  Future<void> _throttleRequests() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestCounter);
    
    // Reset counter every minute
    if (elapsed.inSeconds >= 60) {
      _requestsInLastMinute = 0;
      _lastRequestCounter = now;
    }
    
    // If we're approaching the limit, delay the request
    if (_requestsInLastMinute >= _maxRequestsPerMinute) {
      final waitTime = Duration(seconds: 60 - elapsed.inSeconds + 1);
      debugPrint('Rate limiting: waiting ${waitTime.inSeconds}s before next request');
      await Future.delayed(waitTime);
      
      // Reset counter after waiting
      _requestsInLastMinute = 0;
      _lastRequestCounter = DateTime.now();
    }
    
    _requestsInLastMinute++;
  }
  
  /// Convert an int to bytes
  Uint8List _intToBytes(int value) {
    final bytes = Uint8List(4);
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
    return bytes;
  }
  
  /// Convert bytes to an int
  int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
  
  /// Clean up resources
  void dispose() {
    if (_isolatePool != null) {
      for (final isolate in _isolatePool!) {
        isolate.kill();
      }
      _isolatePool = null;
      _sendPorts = null;
    }
    
    _memoryCache.clear();
  }
}

/// Class to represent a vector tile
class VectorTile {
  final Map<String, dynamic> tileData;
  final ui.Image image;
  final Uint8List pngBytes;
  final int z;
  final int x;
  final int y;
  
  VectorTile({
    required this.tileData,
    required this.image,
    required this.pngBytes,
    required this.z,
    required this.x,
    required this.y,
  });
} 