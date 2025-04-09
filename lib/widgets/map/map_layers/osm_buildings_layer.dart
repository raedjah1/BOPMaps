import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path

import 'osm_data_processor.dart';

/// A custom layer to render OpenStreetMap buildings in 2.5D
class OSMBuildingsLayer extends StatefulWidget {
  final Color buildingBaseColor;
  final Color buildingTopColor;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  
  const OSMBuildingsLayer({
    Key? key,
    this.buildingBaseColor = const Color(0xFF323232),
    this.buildingTopColor = const Color(0xFF4A4A4A),
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
  }) : super(key: key);

  @override
  State<OSMBuildingsLayer> createState() => _OSMBuildingsLayerState();
}

class _OSMBuildingsLayerState extends State<OSMBuildingsLayer> {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _buildings = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }
  
  @override
  void didUpdateWidget(OSMBuildingsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Fetch new building data when map bounds change significantly
    if (oldWidget.visibleBounds != widget.visibleBounds) {
      _fetchBuildings();
    }
  }
  
  void _fetchBuildings() async {
    setState(() {
      _isLoading = true;
    });
    
    // Use the map bounds to fetch buildings
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final buildings = await _dataProcessor.fetchBuildingData(southwest, northeast);
    
    if (mounted) {
      setState(() {
        _buildings = buildings;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while loading or if buildings list is empty
    if (_isLoading || _buildings.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return CustomPaint(
      painter: OSMBuildingsPainter(
        buildings: _buildings,
        buildingBaseColor: widget.buildingBaseColor,
        buildingTopColor: widget.buildingTopColor,
        tiltFactor: widget.tiltFactor,
        zoomLevel: widget.zoomLevel,
        mapBounds: widget.visibleBounds,
      ),
      size: Size.infinite,
    );
  }
}

/// Custom painter to render buildings in 2.5D
class OSMBuildingsPainter extends CustomPainter {
  final List<Map<String, dynamic>> buildings;
  final Color buildingBaseColor;
  final Color buildingTopColor;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds mapBounds;
  final math.Random _random = math.Random(42); // Consistent seed for reproducibility
  
  OSMBuildingsPainter({
    required this.buildings,
    required this.buildingBaseColor,
    required this.buildingTopColor,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.mapBounds,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (buildings.isEmpty) return;
    
    // Initialize MapCamera with correct constructor arguments
    final mapCamera = MapCamera(
      crs: const Epsg3857(),
      zoom: zoomLevel,
      center: const LatLng(0, 0), // Center doesn't matter for screen projection
      size: CustomPoint<double>(size.width, size.height),
      nonRotatedSize: CustomPoint<double>(size.width, size.height),
      rotation: 0.0,
    );
    
    // Enhanced elevation factor for more pronounced 3D effect
    final elevationFactor = tiltFactor * _getZoomFactor(zoomLevel) * 1.5;
    
    for (final building in buildings) {
      final levels = (building['levels'] as num?)?.toDouble() ?? 1.0;
      final points = building['points'] as List<LatLng>;
      
      if (points.length < 3) continue;
      
      // Calculate building height based on number of levels
      final buildingHeight = _calculateBuildingHeight(levels);
      
      // Convert geographical coordinates to screen coordinates
      final screenPoints = points.map((point) {
        final pixelPos = mapCamera.project(point);
        return Offset(pixelPos.x.toDouble(), pixelPos.y.toDouble() - buildingHeight * elevationFactor);
      }).toList();
      
      // Calculate base points (ground level)
      final baseScreenPoints = points.map((point) {
        final pixelPos = mapCamera.project(point);
        return Offset(pixelPos.x.toDouble(), pixelPos.y.toDouble());
      }).toList();
      
      // Create the base building polygon - Use dart:ui Path
      final basePath = Path()..addPolygon(screenPoints, true);
      
      // Draw the base (wall)
      final basePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _variateColor(buildingBaseColor);
      
      canvas.drawPath(basePath, basePaint);
      
      // Draw the extruded top face (roof) - Use dart:ui Path
      final Path roofPath = Path();
      final List<Offset> roofPoints = screenPoints.map((point) {
        return Offset(point.dx, point.dy - buildingHeight);
      }).toList();
      
      roofPath.addPolygon(roofPoints, true);
      
      final roofPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _variateColor(buildingTopColor);
      
      canvas.drawPath(roofPath, roofPaint);
      
      // Draw sides to connect base and roof
      for (int i = 0; i < screenPoints.length; i++) {
        final int nextIndex = (i + 1) % screenPoints.length;
        final Offset p1 = screenPoints[i];
        final Offset p2 = screenPoints[nextIndex];
        final Offset p3 = roofPoints[nextIndex];
        final Offset p4 = roofPoints[i];
        
        final Path sidePath = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();
        
        // Create a slightly darker color for the sides
        final sidePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = _darkenColor(_variateColor(buildingBaseColor), 0.85);
        
        canvas.drawPath(sidePath, sidePaint);
      }
      
      // Add windows if the building is large enough
      if (buildingHeight > 15 && screenPoints.length >= 4) {
        _drawWindows(canvas, screenPoints, buildingHeight);
      }
    }
  }
  
  /// Calculate the center point of a polygon
  LatLng _calculateCenter(List<LatLng> points) {
    double latSum = 0;
    double lngSum = 0;
    
    for (final point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    
    return LatLng(latSum / points.length, lngSum / points.length);
  }
  
  /// Add slight variation to building colors for visual interest
  Color _variateColor(Color baseColor) {
    // Add a small random variation to the color for visual interest
    final variation = (_random.nextDouble() * 0.2) - 0.1; // -0.1 to +0.1
    
    return Color.fromARGB(
      baseColor.alpha,
      (baseColor.red * (1 + variation)).clamp(0, 255).toInt(),
      (baseColor.green * (1 + variation)).clamp(0, 255).toInt(),
      (baseColor.blue * (1 + variation)).clamp(0, 255).toInt(),
    );
  }
  
  /// Darken a color by the specified factor
  Color _darkenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).round(),
      (color.green * factor).round(),
      (color.blue * factor).round(),
    );
  }
  
  /// Draw windows on large buildings for added detail
  void _drawWindows(Canvas canvas, List<Offset> screenPoints, double buildingHeight) {
    // Find the longest segment to place windows along
    double maxLength = 0;
    int longestSegmentStart = 0;
    
    for (int i = 0; i < screenPoints.length; i++) {
      final int nextIndex = (i + 1) % screenPoints.length;
      final Offset p1 = screenPoints[i];
      final Offset p2 = screenPoints[nextIndex];
      
      final double length = (p2 - p1).distance;
      if (length > maxLength) {
        maxLength = length;
        longestSegmentStart = i;
      }
    }
    
    // Only draw windows if the segment is long enough
    if (maxLength < 30) return;
    
    final int nextIndex = (longestSegmentStart + 1) % screenPoints.length;
    final Offset startPoint = screenPoints[longestSegmentStart];
    final Offset endPoint = screenPoints[nextIndex];
    
    // Calculate direction vector
    final double dx = endPoint.dx - startPoint.dx;
    final double dy = endPoint.dy - startPoint.dy;
    
    // Number of windows based on segment length
    final int windowCount = (maxLength / 15).floor();
    if (windowCount <= 0) return;
    
    // Number of window rows
    final int rowCount = (buildingHeight / 15).floor();
    if (rowCount <= 0) return;
    
    // Draw windows
    for (int row = 0; row < rowCount; row++) {
      for (int i = 0; i < windowCount; i++) {
        // Position along the segment
        final double t = (i + 0.5) / windowCount;
        final double x = startPoint.dx + dx * t;
        final double y = startPoint.dy + dy * t;
        
        // Window dimensions
        final double windowWidth = 5;
        final double windowHeight = 8;
        
        // Position vertically based on row
        final double yOffset = (row + 0.5) * (buildingHeight / rowCount);
        
        // Window color based on "lit" status
        final bool isLit = _random.nextDouble() > 0.4; // 60% of windows are lit
        final Color windowColor = isLit 
            ? const Color(0xFFFFE57F).withOpacity(0.8) 
            : const Color(0xFF555555).withOpacity(0.6);
        
        final windowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = windowColor;
        
        // Draw the window
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, y - yOffset),
            width: windowWidth,
            height: windowHeight,
          ),
          windowPaint,
        );
      }
    }
  }
  
  /// Calculate zoom factor for scaling building heights based on zoom level
  double _getZoomFactor(double zoom) {
    // Enhanced zoom factor calculation for more dramatic 3D effect
    return math.max(0.5, (zoom - 10) / 8);
  }

  /// Calculate building height based on number of levels
  double _calculateBuildingHeight(double levels) {
    // Enhanced height calculation - making taller buildings more pronounced
    return math.max(3.0, levels * 2.5);
  }
  
  @override
  bool shouldRepaint(OSMBuildingsPainter oldDelegate) {
    return oldDelegate.buildings != buildings ||
           oldDelegate.buildingBaseColor != buildingBaseColor ||
           oldDelegate.buildingTopColor != buildingTopColor ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.mapBounds != mapBounds;
  }
} 