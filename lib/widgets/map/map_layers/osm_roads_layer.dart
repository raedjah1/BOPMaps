import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path

import 'osm_data_processor.dart';

/// A custom layer to render OpenStreetMap roads in 2.5D
class OSMRoadsLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  
  const OSMRoadsLayer({
    Key? key,
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
  }) : super(key: key);

  @override
  State<OSMRoadsLayer> createState() => _OSMRoadsLayerState();
}

class _OSMRoadsLayerState extends State<OSMRoadsLayer> {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _roads = [];
  bool _isLoading = true;
  
  // Road colors by type
  final Map<String, Color> _roadColors = {
    'motorway': const Color(0xFFE67E22),
    'trunk': const Color(0xFFE74C3C),
    'primary': const Color(0xFFF39C12),
    'secondary': const Color(0xFFF1C40F),
    'tertiary': const Color(0xFFFFFFFF),
    'residential': const Color(0xFFECF0F1),
    'service': const Color(0xFFBDC3C7),
    'unclassified': const Color(0xFFBDC3C7),
    'living_street': const Color(0xFFD5DBDB),
    'pedestrian': const Color(0xFF85929E),
    'footway': const Color(0xFFCE93D8),
    'cycleway': const Color(0xFF4DB6AC),
    'path': const Color(0xFFBCAAA4),
    'track': const Color(0xFFBCAAA4),
  };
  
  @override
  void initState() {
    super.initState();
    _fetchRoads();
  }
  
  @override
  void didUpdateWidget(OSMRoadsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Fetch new road data when map bounds change significantly
    if (oldWidget.visibleBounds != widget.visibleBounds) {
      _fetchRoads();
    }
  }
  
  void _fetchRoads() async {
    setState(() {
      _isLoading = true;
    });
    
    // Use the map bounds to fetch roads
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final roads = await _dataProcessor.fetchRoadData(southwest, northeast);
    
    if (mounted) {
      setState(() {
        _roads = roads;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while loading or if roads list is empty
    if (_isLoading || _roads.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return CustomPaint(
      painter: OSMRoadsPainter(
        roads: _roads,
        roadColors: _roadColors,
        tiltFactor: widget.tiltFactor,
        zoomLevel: widget.zoomLevel,
        mapBounds: widget.visibleBounds,
      ),
      size: Size.infinite,
    );
  }
}

/// Custom painter to render roads in 2.5D
class OSMRoadsPainter extends CustomPainter {
  final List<Map<String, dynamic>> roads;
  final Map<String, Color> roadColors;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds mapBounds;
  
  OSMRoadsPainter({
    required this.roads,
    required this.roadColors,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.mapBounds,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Skip rendering if tilt is too small
    if (tiltFactor < 0.05) return;
    
    // Sort roads by importance (render less important roads first)
    final sortedRoads = _sortRoadsByImportance(roads);
    
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // Draw each road
    for (final road in sortedRoads) {
      final List<LatLng> points = road['points'] as List<LatLng>;
      if (points.length < 2) continue; // Skip invalid roads
      
      final String roadType = road['type'] as String;
      final double roadWidth = (road['width'] as double) * _getZoomFactor(zoomLevel);
      final double elevation = (road['elevation'] as double) * tiltFactor * _getZoomFactor(zoomLevel) * 2;
      
      // Get road color from the map or use default
      Color roadColor = roadColors[roadType] ?? const Color(0xFFBDC3C7);
      
      // Convert LatLng points to screen coordinates
      final List<Offset> screenPoints = points.map((latLng) {
        // Map from LatLng to screen coordinates
        final double x = (latLng.longitude - sw.longitude) / mapWidth * size.width;
        final double y = (1 - (latLng.latitude - sw.latitude) / mapHeight) * size.height;
        return Offset(x, y - elevation); // Apply elevation for 2.5D effect
      }).toList();
      
      // Draw the road with a stroke
      _drawRoadWithStroke(canvas, screenPoints, roadWidth, roadColor);
      
      // Add road details for certain road types at higher zoom levels
      if (zoomLevel >= 16 && _isMainRoad(roadType)) {
        _addRoadDetails(canvas, screenPoints, roadWidth, roadType);
      }
    }
  }
  
  /// Sort roads by importance to ensure proper rendering order
  List<Map<String, dynamic>> _sortRoadsByImportance(List<Map<String, dynamic>> roadList) {
    // Define road importance ranking
    const Map<String, int> importance = {
      'footway': 1,
      'path': 2,
      'track': 3,
      'cycleway': 4,
      'service': 5,
      'living_street': 6,
      'pedestrian': 7,
      'residential': 8,
      'unclassified': 9,
      'tertiary': 10,
      'secondary': 11,
      'primary': 12,
      'trunk': 13,
      'motorway': 14,
    };
    
    // Sort by importance (less important first)
    return List<Map<String, dynamic>>.from(roadList)
      ..sort((a, b) {
        final typeA = a['type'] as String;
        final typeB = b['type'] as String;
        
        final importanceA = importance[typeA] ?? 0;
        final importanceB = importance[typeB] ?? 0;
        
        return importanceA.compareTo(importanceB);
      });
  }
  
  /// Check if the road type is a main road
  bool _isMainRoad(String roadType) {
    return ['motorway', 'trunk', 'primary', 'secondary', 'tertiary'].contains(roadType);
  }
  
  /// Calculate zoom factor for scaling elements based on zoom level
  double _getZoomFactor(double zoom) {
    return math.max(0.5, (zoom - 10) / 10); // Scale factor based on zoom
  }
  
  /// Draw a road with a stroke for a more polished look
  void _drawRoadWithStroke(Canvas canvas, List<Offset> points, double width, Color color) {
    // Draw roads as paths
    if (points.length < 2) return;
    
    // Create road path - use dart:ui Path
    final Path roadPath = Path();
    roadPath.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      roadPath.lineTo(points[i].dx, points[i].dy);
    }
    
    // Draw road with a border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withOpacity(0.5);
    
    canvas.drawPath(roadPath, borderPaint);
    
    // Draw the actual road
    final Paint roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    
    canvas.drawPath(roadPath, roadPaint);
  }
  
  /// Add details to main roads like lane markings
  void _addRoadDetails(Canvas canvas, List<Offset> points, double width, String roadType) {
    if (points.length < 2) return;
    
    // Only add details to larger roads
    if (width < 3.0) return;
    
    // Create center line path for main roads
    if (_isMainRoad(roadType)) {
      final Path centerPath = Path();
      centerPath.moveTo(points[0].dx, points[0].dy);
      
      for (int i = 1; i < points.length; i++) {
        centerPath.lineTo(points[i].dx, points[i].dy);
      }
      
      // Lane marking style based on road type
      final bool isDashed = roadType != 'motorway' && roadType != 'trunk';
      
      // Create lane marking paint
      final Paint markingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.yellow.withOpacity(0.7);
      
      // Apply dashed effect for appropriate road types
      if (isDashed) {
        markingPaint.strokeWidth = 0.8;
        markingPaint.color = Colors.white.withOpacity(0.6);
        
        // Draw dashed line
        _drawDashedLine(canvas, points, markingPaint);
      } else {
        // Draw solid line for motorways/trunks
        canvas.drawPath(centerPath, markingPaint);
      }
    }
  }
  
  /// Helper to draw a dashed line along a series of points
  void _drawDashedLine(Canvas canvas, List<Offset> points, Paint paint) {
    // Skip if too few points
    if (points.length < 2) return;
    
    // Dash pattern
    const double dashLength = 5;
    const double gapLength = 5;
    
    // Track distance along the line
    double currentDistance = 0;
    bool drawing = true; // Start with a dash
    
    for (int i = 0; i < points.length - 1; i++) {
      final Offset start = points[i];
      final Offset end = points[i + 1];
      
      final double segmentLength = (end - start).distance;
      double segmentProgress = 0;
      
      while (segmentProgress < segmentLength) {
        // Calculate remaining length in current dash or gap
        final double remainingPattern = drawing ? dashLength : gapLength;
        final double remainingSegment = segmentLength - segmentProgress;
        
        // Draw dash if we're in drawing mode
        if (drawing) {
          final double dashToDraw = math.min(remainingPattern, remainingSegment);
          final double fraction = dashToDraw / segmentLength;
          final Offset dashStart = Offset(
            start.dx + (end.dx - start.dx) * (segmentProgress / segmentLength),
            start.dy + (end.dy - start.dy) * (segmentProgress / segmentLength),
          );
          final Offset dashEnd = Offset(
            start.dx + (end.dx - start.dx) * ((segmentProgress + dashToDraw) / segmentLength),
            start.dy + (end.dy - start.dy) * ((segmentProgress + dashToDraw) / segmentLength),
          );
          
          canvas.drawLine(dashStart, dashEnd, paint);
        }
        
        // Progress along segment and update state
        final double stepSize = math.min(remainingPattern, remainingSegment);
        segmentProgress += stepSize;
        currentDistance += stepSize;
        
        // Switch between dash and gap
        if (currentDistance >= (drawing ? dashLength : gapLength)) {
          drawing = !drawing;
          currentDistance = 0;
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(OSMRoadsPainter oldDelegate) {
    return oldDelegate.roads != roads ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.mapBounds != mapBounds;
  }
} 