import 'dart:math' as math;

/// Utility class for calculating the size of map data for offline storage
class MapSizeCalculator {
  /// Average tile size in bytes - this is an approximation and varies by map style and content
  static const double averageTileSizeKB = 15.0;
  
  /// Average vector tile size in bytes - typically smaller than raster tiles
  static const double averageVectorTileSizeKB = 8.0;
  
  /// Average satellite tile size in KB - typically larger due to image data
  static const double averageSatelliteTileSizeKB = 40.0;
  
  /// Base URL for OpenStreetMap tiles
  static const String osmTileUrlBase = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Calculates estimated number of tiles for a bounding box at a specific zoom level
  static int calculateTileCount(
    double north, 
    double south, 
    double east, 
    double west, 
    int zoom
  ) {
    // Convert lat/lng bounds to tile coordinates
    final northTile = _latToTileY(north, zoom).floor();
    final southTile = _latToTileY(south, zoom).floor();
    final westTile = _lngToTileX(west, zoom).floor();
    final eastTile = _lngToTileX(east, zoom).floor();
    
    // Calculate the number of tiles in each dimension
    final tilesX = (eastTile - westTile).abs() + 1;
    final tilesY = (southTile - northTile).abs() + 1;
    
    return tilesX * tilesY;
  }
  
  /// Calculates the total number of tiles for a bounding box across a range of zoom levels
  static int calculateTotalTiles(
    double north, 
    double south, 
    double east, 
    double west, 
    int minZoom, 
    int maxZoom
  ) {
    int totalTiles = 0;
    
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      totalTiles += calculateTileCount(north, south, east, west, zoom);
    }
    
    return totalTiles;
  }
  
  /// Estimates the size in KB for downloading tiles in the given bounding box and zoom range
  static double estimateSizeKB(
    double north, 
    double south, 
    double east, 
    double west, 
    int minZoom, 
    int maxZoom, {
    double tileSizeKB = averageTileSizeKB,
  }) {
    final totalTiles = calculateTotalTiles(north, south, east, west, minZoom, maxZoom);
    return totalTiles * tileSizeKB;
  }
  
  /// Estimates the size in MB for downloading tiles in the given bounding box and zoom range
  static double estimateSizeMB(
    double north, 
    double south, 
    double east, 
    double west, 
    int minZoom, 
    int maxZoom, {
    double tileSizeKB = averageTileSizeKB,
  }) {
    return estimateSizeKB(north, south, east, west, minZoom, maxZoom, tileSizeKB: tileSizeKB) / 1024;
  }
  
  /// Formats the estimated size into a human-readable string
  static String formatEstimatedSize(
    double north, 
    double south, 
    double east, 
    double west, 
    int minZoom, 
    int maxZoom, {
    double tileSizeKB = averageTileSizeKB,
  }) {
    final sizeKB = estimateSizeKB(north, south, east, west, minZoom, maxZoom, tileSizeKB: tileSizeKB);
    
    if (sizeKB < 1024) {
      return '${sizeKB.toStringAsFixed(1)} KB';
    } else {
      final sizeMB = sizeKB / 1024;
      if (sizeMB < 1024) {
        return '${sizeMB.toStringAsFixed(1)} MB';
      } else {
        final sizeGB = sizeMB / 1024;
        return '${sizeGB.toStringAsFixed(2)} GB';
      }
    }
  }
  
  /// Calculates the area of the bounding box in square kilometers
  static double calculateAreaKm2(double north, double south, double east, double west) {
    // Approximate radius of Earth in kilometers
    const earthRadius = 6371.0;
    
    // Convert to radians
    final northRad = _degreesToRadians(north);
    final southRad = _degreesToRadians(south);
    final eastRad = _degreesToRadians(east);
    final westRad = _degreesToRadians(west);
    
    // Calculate width and height
    final width = earthRadius * math.cos((northRad + southRad) / 2) * (eastRad - westRad);
    final height = earthRadius * (northRad - southRad);
    
    return width.abs() * height.abs();
  }
  
  /// Helper function to convert latitude to tile Y coordinate
  static double _latToTileY(double lat, int zoom) {
    final radians = _degreesToRadians(lat);
    return (1.0 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2 * (1 << zoom);
  }
  
  /// Helper function to convert longitude to tile X coordinate
  static double _lngToTileX(double lng, int zoom) {
    return (lng + 180.0) / 360.0 * (1 << zoom);
  }
  
  /// Helper function to convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
  
  /// Calculates the download time estimate based on connection speed in Mbps
  static String estimateDownloadTime(double sizeKB, double connectionSpeedMbps) {
    // Convert KB to Mb (kilobits)
    final sizeKb = sizeKB * 8;
    // Calculate download time in seconds
    final downloadTimeSeconds = sizeKb / (connectionSpeedMbps * 1000);
    
    if (downloadTimeSeconds < 60) {
      return '${downloadTimeSeconds.toStringAsFixed(0)} seconds';
    } else if (downloadTimeSeconds < 3600) {
      return '${(downloadTimeSeconds / 60).toStringAsFixed(1)} minutes';
    } else {
      return '${(downloadTimeSeconds / 3600).toStringAsFixed(1)} hours';
    }
  }
} 