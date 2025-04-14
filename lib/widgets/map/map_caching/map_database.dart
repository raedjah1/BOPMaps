import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A database class for efficiently caching OpenStreetMap data and downloaded map regions.
/// This enables the app to work offline and improves performance by reducing API calls.
class MapDatabase {
  static final MapDatabase _instance = MapDatabase._internal();
  static const String _databaseName = 'bop_maps.db';
  static const int _databaseVersion = 1;
  
  // Table names
  static const String tableTiles = 'map_tiles';
  static const String tableBuildings = 'buildings';
  static const String tableRoads = 'roads';
  static const String tablePOIs = 'pois';
  static const String tableRegions = 'downloaded_regions';
  static const String tableAccessLog = 'region_access_log';
  
  Database? _database;
  final Completer<Database> _databaseCompleter = Completer<Database>();
  
  // Factory constructor
  factory MapDatabase() {
    return _instance;
  }
  
  // Private constructor
  MapDatabase._internal() {
    _initDatabase();
  }
  
  // Initialize the database
  Future<void> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      
      // Open the database
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      _databaseCompleter.complete(_database);
    } catch (e) {
      debugPrint('Error initializing map database: $e');
      _databaseCompleter.completeError(e);
    }
  }
  
  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Map tiles table
    await db.execute('''
      CREATE TABLE $tableTiles (
        id TEXT PRIMARY KEY,
        zoom INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        data BLOB NOT NULL,
        timestamp INTEGER NOT NULL,
        source TEXT NOT NULL
      )
    ''');
    
    // Buildings table
    await db.execute('''
      CREATE TABLE $tableBuildings (
        id TEXT PRIMARY KEY,
        bounds TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        zoom_level INTEGER NOT NULL
      )
    ''');
    
    // Roads table
    await db.execute('''
      CREATE TABLE $tableRoads (
        id TEXT PRIMARY KEY,
        bounds TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        zoom_level INTEGER NOT NULL
      )
    ''');
    
    // Points of interest table
    await db.execute('''
      CREATE TABLE $tablePOIs (
        id TEXT PRIMARY KEY,
        bounds TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        zoom_level INTEGER NOT NULL
      )
    ''');
    
    // Downloaded regions table
    await db.execute('''
      CREATE TABLE $tableRegions (
        id TEXT PRIMARY KEY,
        name TEXT,
        bounds TEXT NOT NULL,
        download_timestamp INTEGER NOT NULL,
        expiry_timestamp INTEGER NOT NULL,
        size_bytes INTEGER NOT NULL,
        zoom_levels TEXT NOT NULL
      )
    ''');
    
    // Region access log table
    await db.execute('''
      CREATE TABLE $tableAccessLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        region_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (region_id) REFERENCES $tableRegions (id) ON DELETE CASCADE
      )
    ''');
    
    // Create indices for faster queries
    await db.execute('CREATE INDEX idx_tiles_zoom_x_y ON $tableTiles (zoom, x, y)');
    await db.execute('CREATE INDEX idx_buildings_bounds ON $tableBuildings (bounds)');
    await db.execute('CREATE INDEX idx_roads_bounds ON $tableRoads (bounds)');
    await db.execute('CREATE INDEX idx_pois_bounds ON $tablePOIs (bounds)');
    await db.execute('CREATE INDEX idx_regions_bounds ON $tableRegions (bounds)');
    await db.execute('CREATE INDEX idx_access_region_time ON $tableAccessLog (region_id, timestamp)');
  }
  
  // Database upgrade logic
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema migrations in future versions
    if (oldVersion < 2 && newVersion >= 2) {
      // Example migration for version 2 (if needed in the future)
    }
  }
  
  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    return _databaseCompleter.future;
  }
  
  // ======= Tile Cache Methods =======
  
  /// Store a map tile in the cache
  Future<void> cacheTile(int zoom, int x, int y, List<int> data, String source) async {
    final db = await database;
    final id = 'tile_${zoom}_${x}_${y}_$source';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      tableTiles,
      {
        'id': id,
        'zoom': zoom,
        'x': x,
        'y': y,
        'data': data,
        'timestamp': timestamp,
        'source': source
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get a cached tile if available
  Future<List<int>?> getCachedTile(int zoom, int x, int y, String source) async {
    final db = await database;
    final id = 'tile_${zoom}_${x}_${y}_$source';
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableTiles,
      columns: ['data'],
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return maps.first['data'] as List<int>;
    }
    
    return null;
  }
  
  /// Clear all cached tiles
  Future<void> clearTileCache() async {
    final db = await database;
    await db.delete(tableTiles);
  }
  
  /// Clear old tiles that haven't been accessed recently
  Future<int> pruneOldTiles(int olderThanDays) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;
    
    return await db.delete(
      tableTiles,
      where: 'timestamp < ?',
      whereArgs: [cutoffTime],
    );
  }
  
  // ======= Building Data Methods =======
  
  /// Cache building data for a specific region and zoom level
  Future<void> cacheBuildingData(
    LatLngBounds bounds,
    Map<String, dynamic> data,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'buildings_${boundsString}_$zoomLevel';
    
    await db.insert(
      tableBuildings,
      {
        'id': id,
        'bounds': boundsString,
        'data': jsonEncode(data),
        'timestamp': timestamp,
        'zoom_level': zoomLevel
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get cached building data if available
  Future<Map<String, dynamic>?> getCachedBuildingData(
    LatLngBounds bounds,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableBuildings,
      columns: ['data', 'timestamp'],
      where: 'bounds = ? AND zoom_level = ?',
      whereArgs: [boundsString, zoomLevel],
    );
    
    if (maps.isNotEmpty) {
      // Update access timestamp
      final id = 'buildings_${boundsString}_$zoomLevel';
      await db.update(
        tableBuildings,
        {'timestamp': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
    }
    
    return null;
  }
  
  // ======= Road Data Methods =======
  
  /// Cache road data for a specific region and zoom level
  Future<void> cacheRoadData(
    LatLngBounds bounds,
    Map<String, dynamic> data,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'roads_${boundsString}_$zoomLevel';
    
    await db.insert(
      tableRoads,
      {
        'id': id,
        'bounds': boundsString,
        'data': jsonEncode(data),
        'timestamp': timestamp,
        'zoom_level': zoomLevel
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get cached road data if available
  Future<Map<String, dynamic>?> getCachedRoadData(
    LatLngBounds bounds,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableRoads,
      columns: ['data', 'timestamp'],
      where: 'bounds = ? AND zoom_level = ?',
      whereArgs: [boundsString, zoomLevel],
    );
    
    if (maps.isNotEmpty) {
      // Update access timestamp
      final id = 'roads_${boundsString}_$zoomLevel';
      await db.update(
        tableRoads,
        {'timestamp': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
    }
    
    return null;
  }
  
  // ======= POI Data Methods =======
  
  /// Cache POI data for a specific region and zoom level
  Future<void> cachePOIData(
    LatLngBounds bounds,
    Map<String, dynamic> data,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'pois_${boundsString}_$zoomLevel';
    
    await db.insert(
      tablePOIs,
      {
        'id': id,
        'bounds': boundsString,
        'data': jsonEncode(data),
        'timestamp': timestamp,
        'zoom_level': zoomLevel
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get cached POI data if available
  Future<Map<String, dynamic>?> getCachedPOIData(
    LatLngBounds bounds,
    int zoomLevel
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    
    final List<Map<String, dynamic>> maps = await db.query(
      tablePOIs,
      columns: ['data', 'timestamp'],
      where: 'bounds = ? AND zoom_level = ?',
      whereArgs: [boundsString, zoomLevel],
    );
    
    if (maps.isNotEmpty) {
      // Update access timestamp
      final id = 'pois_${boundsString}_$zoomLevel';
      await db.update(
        tablePOIs,
        {'timestamp': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
    }
    
    return null;
  }
  
  // ======= Region Management Methods =======
  
  /// Register a downloaded region
  Future<void> registerDownloadedRegion(
    String id,
    String name,
    LatLngBounds bounds,
    int expiryDays,
    int sizeBytes,
    List<int> zoomLevels
  ) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    final downloadTimestamp = DateTime.now().millisecondsSinceEpoch;
    final expiryTimestamp = DateTime.now()
        .add(Duration(days: expiryDays))
        .millisecondsSinceEpoch;
    
    await db.insert(
      tableRegions,
      {
        'id': id,
        'name': name,
        'bounds': boundsString,
        'download_timestamp': downloadTimestamp,
        'expiry_timestamp': expiryTimestamp,
        'size_bytes': sizeBytes,
        'zoom_levels': jsonEncode(zoomLevels)
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Log the first access
    await logRegionAccess(id);
  }
  
  /// Get all downloaded regions
  Future<List<Map<String, dynamic>>> getDownloadedRegions() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(tableRegions);
    
    return maps.map((map) {
      final bounds = _decodeBounds(map['bounds'] as String);
      final zoomLevels = jsonDecode(map['zoom_levels'] as String) as List<dynamic>;
      
      return {
        'id': map['id'],
        'name': map['name'],
        'bounds': bounds,
        'download_timestamp': map['download_timestamp'],
        'expiry_timestamp': map['expiry_timestamp'],
        'size_bytes': map['size_bytes'],
        'zoom_levels': zoomLevels.cast<int>(),
      };
    }).toList();
  }
  
  /// Check if a region is available in the cache
  Future<bool> isRegionAvailable(LatLngBounds bounds, int zoomLevel) async {
    final db = await database;
    final boundsString = _encodeBounds(bounds);
    
    // Check in the downloaded regions table
    final List<Map<String, dynamic>> maps = await db.query(
      tableRegions,
      columns: ['id', 'zoom_levels'],
      where: 'bounds = ?',
      whereArgs: [boundsString],
    );
    
    if (maps.isNotEmpty) {
      final zoomLevels = jsonDecode(maps.first['zoom_levels'] as String) as List<dynamic>;
      final id = maps.first['id'] as String;
      
      if (zoomLevels.cast<int>().contains(zoomLevel)) {
        // Log access to this region
        await logRegionAccess(id);
        return true;
      }
    }
    
    return false;
  }
  
  /// Delete a downloaded region and its data
  Future<void> deleteRegion(String regionId) async {
    final db = await database;
    
    // Get the bounds of the region
    final List<Map<String, dynamic>> maps = await db.query(
      tableRegions,
      columns: ['bounds', 'zoom_levels'],
      where: 'id = ?',
      whereArgs: [regionId],
    );
    
    if (maps.isNotEmpty) {
      final boundsString = maps.first['bounds'] as String;
      final zoomLevels = jsonDecode(maps.first['zoom_levels'] as String) as List<dynamic>;
      
      // Begin transaction
      await db.transaction((txn) async {
        // Delete the region record
        await txn.delete(
          tableRegions,
          where: 'id = ?',
          whereArgs: [regionId],
        );
        
        // Delete access logs
        await txn.delete(
          tableAccessLog,
          where: 'region_id = ?',
          whereArgs: [regionId],
        );
        
        // Delete related building data
        for (final zoomLevel in zoomLevels.cast<int>()) {
          final buildingId = 'buildings_${boundsString}_$zoomLevel';
          await txn.delete(
            tableBuildings,
            where: 'id = ?',
            whereArgs: [buildingId],
          );
          
          final roadId = 'roads_${boundsString}_$zoomLevel';
          await txn.delete(
            tableRoads,
            where: 'id = ?',
            whereArgs: [roadId],
          );
          
          final poiId = 'pois_${boundsString}_$zoomLevel';
          await txn.delete(
            tablePOIs,
            where: 'id = ?',
            whereArgs: [poiId],
          );
        }
        
        // Delete related map tiles (approximate by bounds)
        final bounds = _decodeBounds(boundsString);
        await _deleteTilesInBounds(txn, bounds, zoomLevels.cast<int>());
      });
    }
  }
  
  /// Delete tiles within specific bounds
  Future<void> _deleteTilesInBounds(
    Transaction txn,
    LatLngBounds bounds,
    List<int> zoomLevels
  ) async {
    // This is a simplification - in a real implementation, 
    // we would calculate the tile coordinates that cover the bounds
    // For now, we'll use a simplified approach based on the bounds string
    final boundsStr = '%${_encodeBounds(bounds)}%';
    
    for (final zoom in zoomLevels) {
      await txn.delete(
        tableTiles,
        where: 'zoom = ? AND id LIKE ?',
        whereArgs: [zoom, boundsStr],
      );
    }
  }
  
  // ======= Usage Statistics Methods =======
  
  /// Log access to a region
  Future<void> logRegionAccess(String regionId) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      tableAccessLog,
      {
        'region_id': regionId,
        'timestamp': timestamp,
      },
    );
  }
  
  /// Get most frequently accessed regions
  Future<List<String>> getMostAccessedRegions({int limit = 5}) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT region_id, COUNT(*) as access_count
      FROM $tableAccessLog
      GROUP BY region_id
      ORDER BY access_count DESC
      LIMIT ?
    ''', [limit]);
    
    return maps.map((map) => map['region_id'] as String).toList();
  }
  
  /// Get recently accessed regions
  Future<List<String>> getRecentlyAccessedRegions({int limit = 5}) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT region_id
      FROM $tableAccessLog
      ORDER BY timestamp DESC
      LIMIT ?
    ''', [limit]);
    
    return maps.map((map) => map['region_id'] as String).toList();
  }
  
  // ======= Utility Methods =======
  
  /// Calculate cache size in bytes
  Future<int> calculateCacheSize() async {
    final db = await database;
    
    // Get tile data size
    final tileResult = await db.rawQuery('SELECT SUM(length(data)) as size FROM $tableTiles');
    final tileSize = tileResult.first['size'] as int? ?? 0;
    
    // Get building data size 
    final buildingResult = await db.rawQuery('SELECT SUM(length(data)) as size FROM $tableBuildings');
    final buildingSize = buildingResult.first['size'] as int? ?? 0;
    
    // Get road data size
    final roadResult = await db.rawQuery('SELECT SUM(length(data)) as size FROM $tableRoads');
    final roadSize = roadResult.first['size'] as int? ?? 0;
    
    // Get POI data size
    final poiResult = await db.rawQuery('SELECT SUM(length(data)) as size FROM $tablePOIs');
    final poiSize = poiResult.first['size'] as int? ?? 0;
    
    return tileSize + buildingSize + roadSize + poiSize;
  }
  
  /// Clear expired data
  Future<int> clearExpiredData() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Begin transaction
    int totalDeleted = 0;
    await db.transaction((txn) async {
      // Get expired regions
      final List<Map<String, dynamic>> expiredRegions = await txn.query(
        tableRegions,
        columns: ['id'],
        where: 'expiry_timestamp < ?',
        whereArgs: [now],
      );
      
      // Delete each expired region and its related data
      for (final region in expiredRegions) {
        final regionId = region['id'] as String;
        await deleteRegion(regionId);
        totalDeleted++;
      }
    });
    
    return totalDeleted;
  }
  
  /// Helper to encode bounds as string
  String _encodeBounds(LatLngBounds bounds) {
    return '${bounds.southWest.latitude},${bounds.southWest.longitude},${bounds.northEast.latitude},${bounds.northEast.longitude}';
  }
  
  /// Helper to decode bounds from string
  LatLngBounds _decodeBounds(String encodedBounds) {
    final parts = encodedBounds.split(',');
    return LatLngBounds(
      LatLng(double.parse(parts[0]), double.parse(parts[1])),
      LatLng(double.parse(parts[2]), double.parse(parts[3])),
    );
  }
  
  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    db.close();
  }
} 