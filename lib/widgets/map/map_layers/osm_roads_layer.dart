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
  final bool isMapMoving;
  
  const OSMRoadsLayer({
    Key? key,
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
    this.isMapMoving = false,
  }) : super(key: key);

  @override
  State<OSMRoadsLayer> createState() => _OSMRoadsLayerState();
}

class _OSMRoadsLayerState extends State<OSMRoadsLayer> {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _roads = [];
  bool _isLoading = true;
  bool _needsRefresh = true;
  String _lastBoundsKey = "";
  
  // Enhanced road colors with vibrant, complementary palette
  final Map<String, Color> _roadColors = {
    'motorway': const Color(0xFFE91E63).withOpacity(0.8),  // Pink/magenta for motorways
    'trunk': const Color(0xFFEC407A).withOpacity(0.7),     // Lighter pink for trunk roads
    'primary': const Color(0xFFF48FB1).withOpacity(0.65),   // Pale pink for primary roads
    'secondary': const Color(0xFFF8BBD0).withOpacity(0.6), // Very light pink for secondary
    'tertiary': const Color(0xFFFFFFFF).withOpacity(0.5),  // White with more opacity for tertiary
    'residential': const Color(0xFFECEFF1).withOpacity(0.4), // Increased opacity for better visibility
    'service': const Color(0xFFCFD8DC).withOpacity(0.35),   // Light gray for service roads
    'unclassified': const Color(0xFFBDBDBD).withOpacity(0.3), // Medium gray for unclassified
    'living_street': const Color(0xFFB0BEC5).withOpacity(0.35), // Blue-gray for living streets
    'pedestrian': const Color(0xFFAED581).withOpacity(0.35),  // Light green for pedestrian ways
    'footway': const Color(0xFFCE93D8).withOpacity(0.35),     // Light purple for footways
    'cycleway': const Color(0xFF4DB6AC).withOpacity(0.35),    // Teal for cycleways
    'path': const Color(0xFFD7CCC8).withOpacity(0.35),        // Beige for paths
    'track': const Color(0xFFBCAAA4).withOpacity(0.35),       // Brown for tracks
  };
  
  // Time of day color variations for roads
  final Map<String, Map<String, Color>> _timeOfDayRoadColors = {
    'morning': {
      'motorway': const Color(0xFFF06292).withOpacity(0.8),  // Softer pink in morning light
      'primary': const Color(0xFFF8BBD0).withOpacity(0.65),  // Very soft pink in morning
    },
    'noon': {
      'motorway': const Color(0xFFE91E63).withOpacity(0.8),  // Bold pink at noon
      'primary': const Color(0xFFF48FB1).withOpacity(0.65),  // Standard pink at noon
    },
    'evening': {
      'motorway': const Color(0xFFD81B60).withOpacity(0.75), // Darker pink in evening
      'primary': const Color(0xFFAD1457).withOpacity(0.6),   // Deep pink in evening
    },
    'night': {
      'motorway': const Color(0xFFC2185B).withOpacity(0.6),  // Muted pink at night
      'primary': const Color(0xFF880E4F).withOpacity(0.5),   // Very dark pink at night
    },
  };
  
  @override
  void initState() {
    super.initState();
    _fetchRoads();
  }
  
  @override
  void didUpdateWidget(OSMRoadsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Get a key to identify current map bounds
    final newBoundsKey = _getBoundsKey();
    
    // Fetch new road data when map bounds change significantly or zoom changes
    if (oldWidget.visibleBounds != widget.visibleBounds || 
        oldWidget.zoomLevel != widget.zoomLevel ||
        _lastBoundsKey != newBoundsKey) {
      
      _needsRefresh = true;
      
      // If map is actively moving, delay the fetch to avoid too many API calls
      if (widget.isMapMoving) {
        _delayedFetch();
      } else {
        _fetchRoads();
      }
    }
  }
  
  // Get a key to identify current map bounds, with reduced precision for fewer unnecessary refreshes
  String _getBoundsKey() {
    final sw = widget.visibleBounds.southWest;
    final ne = widget.visibleBounds.northEast;
    
    // Reduce precision for bounds (3 decimal places ≈ 100m accuracy)
    final key = '${sw.latitude.toStringAsFixed(3)},${sw.longitude.toStringAsFixed(3)}_'
               '${ne.latitude.toStringAsFixed(3)},${ne.longitude.toStringAsFixed(3)}_'
               '${widget.zoomLevel.toStringAsFixed(1)}';
    return key;
  }
  
  // Delay fetch to prevent excessive API calls during continuous panning/zooming
  void _delayedFetch() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _needsRefresh) {
        _fetchRoads();
      }
    });
  }
  
  void _fetchRoads() async {
    setState(() {
      _isLoading = true;
    });
    
    // Update bounds key
    _lastBoundsKey = _getBoundsKey();
    
    // Use the map bounds to fetch roads
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final roads = await _dataProcessor.fetchRoadData(southwest, northeast);
    
    if (mounted) {
      setState(() {
        _roads = roads;
        _isLoading = false;
        _needsRefresh = false;
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
    
    // Enhanced styling for different road types
    final Color borderColor = _getBorderColorForRoad(color);
    final double borderWidth = width + 1.5; // Increased border width
    
    // Draw road with a border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = borderColor;
    
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
  
  /// Get border color based on road color (more sophisticated border effect)
  Color _getBorderColorForRoad(Color roadColor) {
    // For pink/magenta roads, use a darker pink border
    if (roadColor.red > 200 && roadColor.green < 150) {
      return const Color(0xFF880E4F).withOpacity(0.5); // Dark pink border
    }
    
    // For white/light gray roads, use a medium gray border
    if (roadColor.red > 220 && roadColor.green > 220 && roadColor.blue > 220) {
      return const Color(0xFF757575).withOpacity(0.5); // Medium gray border
    }
    
    // For light green (pedestrian)
    if (roadColor.green > 180 && roadColor.red < 180) {
      return const Color(0xFF33691E).withOpacity(0.4); // Dark green border
    }
    
    // For light purple (footways)
    if (roadColor.red > 180 && roadColor.blue > 180 && roadColor.green < 150) {
      return const Color(0xFF6A1B9A).withOpacity(0.4); // Dark purple border
    }
    
    // Default dark border
    return Colors.black.withOpacity(0.4);
  }
  
  /// Add details to main roads like lane markings with enhanced styling
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
      
      // Enhanced lane marking colors based on road type
      Color markingColor;
      if (roadType == 'motorway' || roadType == 'trunk') {
        markingColor = Colors.white.withOpacity(0.85); // Brighter white for highways
      } else if (roadType == 'primary') {
        markingColor = Colors.white.withOpacity(0.75); // White for primary roads
      } else {
        markingColor = Colors.white.withOpacity(0.65); // Standard white for other roads
      }
      
      // Create lane marking paint with enhanced styling
      final Paint markingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadType == 'motorway' ? 1.2 : 0.9 // Thicker lines for highways
        ..color = markingColor;
      
      // Apply dashed effect for appropriate road types
      if (isDashed) {
        // Draw dashed line
        _drawDashedLine(canvas, points, markingPaint);
      } else {
        // Draw solid line for motorways/trunks
        canvas.drawPath(centerPath, markingPaint);
        
        // For motorways, add an additional lane line if the road is wide enough
        if (roadType == 'motorway' && width > 7.0) {
          _addMultipleLanes(canvas, points, width, markingPaint);
        }
      }
    }
  }
  
  /// Add multiple lane markings for wide highways
  void _addMultipleLanes(Canvas canvas, List<Offset> points, double width, Paint markingPaint) {
    if (points.length < 4) return; // Need more points for realistic offset
    
    // Calculate lane offsets (perpendicular to road direction)
    final List<List<Offset>> laneOffsets = [];
    const int lanesCount = 2; // Number of lane markings
    
    for (int lane = 1; lane <= lanesCount; lane++) {
      final List<Offset> lanePoints = [];
      final double lanePosition = width * 0.33 * lane; // Position each lane at 1/3 and 2/3 of width
      
      for (int i = 1; i < points.length - 1; i++) {
        // Calculate perpendicular vector
        final Offset prev = points[i - 1];
        final Offset curr = points[i];
        final Offset next = points[i + 1];
        
        // Direction vector along the road
        final Offset dir = Offset(
          (next.dx - prev.dx) / 2,
          (next.dy - prev.dy) / 2,
        );
        
        // Normalize the direction vector manually
        final double dirLength = math.sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
        final Offset normalizedDir = dirLength > 0 
            ? Offset(dir.dx / dirLength, dir.dy / dirLength)
            : Offset(0, 0);
        
        // Perpendicular vector (rotate 90 degrees)
        final Offset perp = Offset(-normalizedDir.dy, normalizedDir.dx);
        
        // Alternate sides for more natural looking lanes
        final double sideMultiplier = (i % 2 == 0) ? 1 : -1;
        
        // Offset this point
        lanePoints.add(Offset(
          curr.dx + perp.dx * lanePosition * sideMultiplier,
          curr.dy + perp.dy * lanePosition * sideMultiplier,
        ));
      }
      
      laneOffsets.add(lanePoints);
    }
    
    // Draw each lane marking
    for (final lanePoints in laneOffsets) {
      // Create a new Paint instance with the desired properties instead of using copyWith
      final Paint lanePaint = Paint()
        ..style = markingPaint.style
        ..strokeWidth = 0.8 // Slightly thinner for lane lines
        ..strokeCap = markingPaint.strokeCap
        ..strokeJoin = markingPaint.strokeJoin
        ..color = Colors.white.withOpacity(0.5); // More transparent
      
      _drawDashedLine(canvas, lanePoints, lanePaint);
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