import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'map_cache_manager.dart';
import '../map_layers/osm_data_processor.dart';

/// A class to manage the download and storage of map data for specific regions,
/// enabling offline use and reducing network requests.
class DataDownloader {
  // Singleton instance
  static final DataDownloader _instance = DataDownloader._internal();
  factory DataDownloader() => _instance;
  
  // Dependency on OSMDataProcessor and cache manager
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  final MapCacheManager _cacheManager = MapCacheManager();
  
  // Status tracking
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  // List of predefined common regions with bounding boxes
  final Map<String, Map<String, dynamic>> _predefinedRegions = {
    'San Francisco': {
      'southwest': LatLng(37.7000, -122.5100),
      'northeast': LatLng(37.8100, -122.3800),
      'zoom_levels': [13, 15, 17],
    },
    'New York': {
      'southwest': LatLng(40.6800, -74.0300),
      'northeast': LatLng(40.8800, -73.9000),
      'zoom_levels': [13, 15, 17],
    },
    'London': {
      'southwest': LatLng(51.4700, -0.2000),
      'northeast': LatLng(51.5400, 0.0500),
      'zoom_levels': [13, 15, 17],
    },
    // Add more predefined regions as needed
  };
  
  // Downloaded regions tracking
  Set<String> _downloadedRegions = {};
  
  DataDownloader._internal() {
    _loadDownloadedRegions();
  }
  
  // Getters for status
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  Set<String> get downloadedRegions => _downloadedRegions;
  Map<String, Map<String, dynamic>> get predefinedRegions => _predefinedRegions;
  
  // Load list of downloaded regions from preferences
  Future<void> _loadDownloadedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regions = prefs.getStringList('downloaded_regions') ?? [];
      _downloadedRegions = regions.toSet();
    } catch (e) {
      debugPrint('Error loading downloaded regions: $e');
    }
  }
  
  // Save list of downloaded regions to preferences
  Future<void> _saveDownloadedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('downloaded_regions', _downloadedRegions.toList());
    } catch (e) {
      debugPrint('Error saving downloaded regions: $e');
    }
  }
  
  // Download map data for a predefined region
  Future<bool> downloadRegion(String regionName) async {
    if (!_predefinedRegions.containsKey(regionName)) {
      debugPrint('Region not found: $regionName');
      return false;
    }
    
    if (_isDownloading) {
      debugPrint('Download already in progress');
      return false;
    }
    
    _isDownloading = true;
    _downloadProgress = 0.0;
    
    final region = _predefinedRegions[regionName]!;
    final southwest = region['southwest'] as LatLng;
    final northeast = region['northeast'] as LatLng;
    final zoomLevels = region['zoom_levels'] as List<int>;
    
    try {
      // Split the region into smaller tiles for more manageable downloads
      final tiles = _splitRegionIntoTiles(southwest, northeast);
      double progressPerTile = 1.0 / (tiles.length * zoomLevels.length * 5); // 5 data types
      int completedTasks = 0;
      int totalTasks = tiles.length * zoomLevels.length * 5;
      
      // Download data for each zoom level and each tile
      for (final zoom in zoomLevels) {
        for (final tile in tiles) {
          // Buildings
          await _downloadAndCacheData(
            'buildings', 
            tile['southwest'] as LatLng,
            tile['northeast'] as LatLng,
            zoom.toDouble(),
          );
          completedTasks++;
          _downloadProgress = completedTasks / totalTasks;
          
          // Roads
          await _downloadAndCacheData(
            'roads', 
            tile['southwest'] as LatLng,
            tile['northeast'] as LatLng,
            zoom.toDouble(),
          );
          completedTasks++;
          _downloadProgress = completedTasks / totalTasks;
          
          // Parks
          await _downloadAndCacheData(
            'parks', 
            tile['southwest'] as LatLng,
            tile['northeast'] as LatLng,
            zoom.toDouble(),
          );
          completedTasks++;
          _downloadProgress = completedTasks / totalTasks;
          
          // Water
          await _downloadAndCacheData(
            'water', 
            tile['southwest'] as LatLng,
            tile['northeast'] as LatLng,
            zoom.toDouble(),
          );
          completedTasks++;
          _downloadProgress = completedTasks / totalTasks;
          
          // POIs
          await _downloadAndCacheData(
            'poi', 
            tile['southwest'] as LatLng,
            tile['northeast'] as LatLng,
            zoom.toDouble(),
          );
          completedTasks++;
          _downloadProgress = completedTasks / totalTasks;
        }
      }
      
      // Mark region as downloaded
      _downloadedRegions.add(regionName);
      await _saveDownloadedRegions();
      
      _isDownloading = false;
      _downloadProgress = 1.0;
      return true;
    } catch (e) {
      debugPrint('Error downloading region: $e');
      _isDownloading = false;
      return false;
    }
  }
  
  // Split a region into smaller tiles for manageable downloads
  List<Map<String, LatLng>> _splitRegionIntoTiles(LatLng southwest, LatLng northeast) {
    final List<Map<String, LatLng>> tiles = [];
    
    // Calculate size
    final latDelta = northeast.latitude - southwest.latitude;
    final lngDelta = northeast.longitude - southwest.longitude;
    
    // Aim for tiles that are roughly 0.04 degrees (about 4km)
    final tilesLat = math.max(1, (latDelta / 0.04).ceil());
    final tilesLng = math.max(1, (lngDelta / 0.04).ceil());
    
    final latStep = latDelta / tilesLat;
    final lngStep = lngDelta / tilesLng;
    
    for (int i = 0; i < tilesLat; i++) {
      for (int j = 0; j < tilesLng; j++) {
        final tileSW = LatLng(
          southwest.latitude + (i * latStep),
          southwest.longitude + (j * lngStep),
        );
        
        final tileNE = LatLng(
          southwest.latitude + ((i + 1) * latStep),
          southwest.longitude + ((j + 1) * lngStep),
        );
        
        tiles.add({
          'southwest': tileSW,
          'northeast': tileNE,
        });
      }
    }
    
    return tiles;
  }
  
  // Download and cache map data for a specific area and data type
  Future<void> _downloadAndCacheData(
    String dataType, 
    LatLng southwest, 
    LatLng northeast, 
    double zoom,
  ) async {
    try {
      dynamic data;
      
      // Check if data is already in cache
      if (_cacheManager.hasInMemoryCache(dataType, southwest, northeast, zoom)) {
        debugPrint('Data already in cache for $dataType ${southwest.latitude},${southwest.longitude}');
        return;
      }
      
      // Use appropriate data processor method based on data type
      switch (dataType) {
        case 'buildings':
          data = await _dataProcessor.fetchBuildingData(southwest, northeast);
          break;
        case 'roads':
          data = await _dataProcessor.fetchRoadData(southwest, northeast);
          break;
        case 'parks':
          data = await _dataProcessor.fetchParksData(southwest, northeast);
          break;
        case 'water':
          data = await _dataProcessor.fetchWaterFeaturesData(southwest, northeast);
          break;
        case 'poi':
          data = await _dataProcessor.fetchPOIData(southwest, northeast);
          break;
        default:
          throw Exception('Unknown data type: $dataType');
      }
      
      // Store data in cache
      if (data != null) {
        _cacheManager.storeInMemoryCache(dataType, southwest, northeast, zoom, data);
      }
    } catch (e) {
      debugPrint('Error downloading data for $dataType: $e');
      // Continue with next download even if this one fails
    }
  }
  
  // Helper method to get current location and download surrounding area
  Future<bool> downloadCurrentLocationArea({double radiusKm = 5.0}) async {
    try {
      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      
      final position = await Geolocator.getCurrentPosition();
      
      // Calculate bounding box for current location
      // Approximately: 1 degree = 111 km
      final degreeDistance = radiusKm / 111.0;
      
      final southwest = LatLng(
        position.latitude - degreeDistance,
        position.longitude - degreeDistance * math.cos(position.latitude * math.pi / 180),
      );
      
      final northeast = LatLng(
        position.latitude + degreeDistance,
        position.longitude + degreeDistance * math.cos(position.latitude * math.pi / 180),
      );
      
      // Create a custom region name based on coordinates
      final regionName = 'Current Location (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})';
      
      // Add to predefined regions temporarily
      _predefinedRegions[regionName] = {
        'southwest': southwest,
        'northeast': northeast,
        'zoom_levels': [13, 15, 17], // Default zoom levels
      };
      
      // Download the region
      return await downloadRegion(regionName);
    } catch (e) {
      debugPrint('Error downloading current location area: $e');
      return false;
    }
  }
  
  // Calculate size of downloaded region data
  Future<int> calculateDownloadedSize(String regionName) async {
    if (!_downloadedRegions.contains(regionName)) {
      return 0;
    }
    
    int totalSize = 0;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final regionDir = Directory('${directory.path}/map_cache/$regionName');
      
      if (await regionDir.exists()) {
        await for (final file in regionDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating region size: $e');
    }
    
    return totalSize;
  }
  
  // Delete a downloaded region
  Future<bool> deleteRegion(String regionName) async {
    if (!_downloadedRegions.contains(regionName)) {
      return false;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final regionDir = Directory('${directory.path}/map_cache/$regionName');
      
      if (await regionDir.exists()) {
        await regionDir.delete(recursive: true);
      }
      
      _downloadedRegions.remove(regionName);
      await _saveDownloadedRegions();
      return true;
    } catch (e) {
      debugPrint('Error deleting region: $e');
      return false;
    }
  }
} 