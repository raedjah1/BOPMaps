import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:ui' as ui;
import 'osm_data_processor.dart';

/// A layer that renders water bodies (lakes, rivers, etc.) in 2.5D
class OSMWaterLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final Color waterColor;
  final Color waterHighlightColor;
  final Color riverColor;
  
  const OSMWaterLayer({
    Key? key,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.visibleBounds,
    this.waterColor = const Color(0xFF2A93D5),
    this.waterHighlightColor = const Color(0xFF3DA9E8),
    this.riverColor = const Color(0xFF4BABDB),
  }) : super(key: key);
  
  @override
  State<OSMWaterLayer> createState() => _OSMWaterLayerState();
}

class _OSMWaterLayerState extends State<OSMWaterLayer> {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _waterBodies = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  @override
  void didUpdateWidget(OSMWaterLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the bounds have changed significantly or zoom level has changed
    if (!_isLoading && 
        (oldWidget.visibleBounds.southWest.latitude != widget.visibleBounds.southWest.latitude ||
         oldWidget.visibleBounds.southWest.longitude != widget.visibleBounds.southWest.longitude ||
         oldWidget.visibleBounds.northEast.latitude != widget.visibleBounds.northEast.latitude ||
         oldWidget.visibleBounds.northEast.longitude != widget.visibleBounds.northEast.longitude ||
         (oldWidget.zoomLevel - widget.zoomLevel).abs() > 0.5)) {
      _fetchData();
    }
  }
  
  Future<void> _fetchData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch water bodies
      final waterBodies = await _dataProcessor.fetchWaterBodies(
        widget.visibleBounds.southWest,
        widget.visibleBounds.northEast,
      );
      
      if (mounted) {
        setState(() {
          _waterBodies = waterBodies;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading water data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WaterPainter(
        waterBodies: _waterBodies,
        tiltFactor: widget.tiltFactor,
        zoomLevel: widget.zoomLevel,
        waterColor: widget.waterColor,
        waterHighlightColor: widget.waterHighlightColor,
        riverColor: widget.riverColor,
      ),
      child: Container(), // Empty container as child
    );
  }
}

class WaterPainter extends CustomPainter {
  final List<Map<String, dynamic>> waterBodies;
  final double tiltFactor;
  final double zoomLevel;
  final Color waterColor;
  final Color waterHighlightColor;
  final Color riverColor;
  
  WaterPainter({
    required this.waterBodies,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.waterColor,
    required this.waterHighlightColor,
    required this.riverColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Skip painting if no water bodies
    if (waterBodies.isEmpty) return;
    
    // Get current map transform - using MapCamera instead of FlutterMapState
    // This approach uses the size parameter directly
    final mapCamera = MapCamera(
      crs: const Epsg3857(),
      zoom: zoomLevel,
      center: const LatLng(0, 0), // Center doesn't matter for screen projection
      size: CustomPoint<double>(size.width, size.height),
      nonRotatedSize: CustomPoint<double>(size.width, size.height),
      rotation: 0.0,
    );
    
    // Calculate elevation factor based on tilt and zoom
    final elevationFactor = tiltFactor * _getZoomFactor(zoomLevel);
    
    // Create painters
    final lakePaint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;
    
    final lakeHighlightPaint = Paint()
      ..color = waterHighlightColor
      ..style = PaintingStyle.fill;
    
    final riverPaint = Paint()
      ..color = riverColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw water bodies
    for (final water in waterBodies) {
      final points = water['points'] as List<LatLng>;
      
      if (points.length < 3) continue;
      
      final type = water['type'] as String;
      final elevation = (water['elevation'] as double?) ?? 0.0;
      
      // Apply more aggressive elevation factor for enhanced 3D effect
      final adjustedElevation = elevation * elevationFactor * 1.5;
      
      // Convert geographical coordinates to screen coordinates
      final screenPoints = points.map((point) {
        final pixelPos = mapCamera.project(point);
        return Offset(pixelPos.x.toDouble(), pixelPos.y.toDouble() - adjustedElevation);
      }).toList();
      
      // Draw different water features differently
      if (type == 'water' || type == 'coastline') {
        // Draw lakes and water bodies
        final path = ui.Path();
        path.moveTo(screenPoints.first.dx, screenPoints.first.dy);
        for (int i = 1; i < screenPoints.length; i++) {
          path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
        }
        path.close();
        
        // Draw a subtle ripple effect on top of lakes for more visual interest
        canvas.drawPath(path, lakePaint);
        
        // Add shimmering highlight effect if tilt is significant
        if (tiltFactor > 0.2) {
          final highlightPath = ui.Path();
          
          // Create a series of sine wave patterns to simulate water surface
          for (int i = 0; i < screenPoints.length - 1; i++) {
            final start = screenPoints[i];
            final end = screenPoints[i + 1];
            final dist = (end - start).distance;
            
            if (dist > 20) { // Only add details to longer segments
              final step = dist / 20; // Number of wave segments
              highlightPath.moveTo(start.dx, start.dy);
              
              for (int j = 1; j <= 20; j++) {
                final t = j / 20;
                final x = start.dx + (end.dx - start.dx) * t;
                final y = start.dy + (end.dy - start.dy) * t + 
                    math.sin(j * math.pi / 2 + (DateTime.now().millisecondsSinceEpoch / 1000)) * 
                    tiltFactor * 2;
                
                highlightPath.lineTo(x, y);
              }
            }
          }
          
          canvas.drawPath(highlightPath, Paint()
            ..color = waterHighlightColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
        }
      } else if (type == 'river' || type == 'stream') {
        // Draw rivers and streams
        // Width depends on type and zoom level
        double strokeWidth = type == 'river' ? 
            3.0 + zoomLevel / 3 : 
            1.5 + zoomLevel / 5;
        
        riverPaint.strokeWidth = strokeWidth;
        
        final path = ui.Path();
        path.moveTo(screenPoints.first.dx, screenPoints.first.dy);
        
        for (int i = 1; i < screenPoints.length; i++) {
          path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
        }
        
        canvas.drawPath(path, riverPaint);
        
        // Add flowing water effect with a lighter color
        if (tiltFactor > 0.2) {
          final flowPath = ui.Path();
          flowPath.moveTo(screenPoints.first.dx, screenPoints.first.dy);
          
          for (int i = 1; i < screenPoints.length; i++) {
            // Add a slight wave pattern
            final t = i / screenPoints.length;
            final wave = math.sin(t * math.pi * 10 + (DateTime.now().millisecondsSinceEpoch / 500)) * 
                tiltFactor * strokeWidth * 0.3;
                
            flowPath.lineTo(
              screenPoints[i].dx + wave, 
              screenPoints[i].dy
            );
          }
          
          canvas.drawPath(flowPath, Paint()
            ..color = waterHighlightColor.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth * 0.5);
        }
      }
    }
  }
  
  /// Calculate zoom factor for scaling elements based on zoom level
  double _getZoomFactor(double zoom) {
    return math.max(0.5, (zoom - 10) / 10); // Scale factor based on zoom
  }
  
  @override
  bool shouldRepaint(WaterPainter oldDelegate) {
    return oldDelegate.waterBodies != waterBodies ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.waterColor != waterColor ||
           oldDelegate.waterHighlightColor != waterHighlightColor ||
           oldDelegate.riverColor != riverColor;
  }
} 