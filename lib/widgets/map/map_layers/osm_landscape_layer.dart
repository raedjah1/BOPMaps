import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:ui' as ui; // Add explicit import for dart:ui
import 'osm_data_processor.dart';

/// A layer that renders landscape features (parks, forests, etc.) in 2.5D
class OSMLandscapeLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final Color parkColor;
  final Color forestColor;
  final Color grasslandColor;
  
  const OSMLandscapeLayer({
    Key? key,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.visibleBounds,
    this.parkColor = const Color(0xFF62A87C),
    this.forestColor = const Color(0xFF2E8B57),
    this.grasslandColor = const Color(0xFF9BC088),
  }) : super(key: key);
  
  @override
  State<OSMLandscapeLayer> createState() => _OSMLandscapeLayerState();
}

class _OSMLandscapeLayerState extends State<OSMLandscapeLayer> {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _landscapeFeatures = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  @override
  void didUpdateWidget(OSMLandscapeLayer oldWidget) {
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
      // Fetch landscape features
      final features = await _dataProcessor.fetchLandscapeFeatures(
        widget.visibleBounds.southWest,
        widget.visibleBounds.northEast,
      );
      
      if (mounted) {
        setState(() {
          _landscapeFeatures = features;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading landscape data: $e');
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
      painter: LandscapePainter(
        landscapeFeatures: _landscapeFeatures,
        tiltFactor: widget.tiltFactor,
        zoomLevel: widget.zoomLevel,
        parkColor: widget.parkColor,
        forestColor: widget.forestColor,
        grasslandColor: widget.grasslandColor,
      ),
      child: Container(), // Empty container as child
    );
  }
}

class LandscapePainter extends CustomPainter {
  final List<Map<String, dynamic>> landscapeFeatures;
  final double tiltFactor;
  final double zoomLevel;
  final Color parkColor;
  final Color forestColor;
  final Color grasslandColor;
  
  // Random seed for consistent texture generation
  final int _seed = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  
  LandscapePainter({
    required this.landscapeFeatures,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.parkColor,
    required this.forestColor,
    required this.grasslandColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (landscapeFeatures.isEmpty) return;
    
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
    
    // Draw landscape features
    for (final feature in landscapeFeatures) {
      final points = feature['points'] as List<LatLng>;
      
      if (points.length < 3) continue;
      
      final type = feature['type'] as String;
      final elevation = (feature['elevation'] as double?) ?? 0.0;
      
      // Convert geographical coordinates to screen coordinates
      final screenPoints = points.map((point) {
        final pixelPos = mapCamera.project(point);
        return Offset(pixelPos.x.toDouble(), pixelPos.y.toDouble() - elevation * elevationFactor);
      }).toList();
      
      // Get appropriate color and texture settings based on feature type
      final StyleSettings style = _getStyleForFeature(type);
      
      // Create base path for the feature
      final path = ui.Path();
      path.moveTo(screenPoints.first.dx, screenPoints.first.dy);
      for (int i = 1; i < screenPoints.length; i++) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
      path.close();
      
      // Draw feature with base color
      canvas.drawPath(path, Paint()
        ..color = style.baseColor
        ..style = PaintingStyle.fill);
      
      // If tilt is significant, add 3D texture details based on the feature type
      if (tiltFactor > 0.1 && style.shouldAddTexture) {
        _addTextureDetails(canvas, screenPoints, style, elevation);
      }
      
      // Add subtle outline for definition
      canvas.drawPath(path, Paint()
        ..color = style.outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
  }
  
  // Add texture details based on feature type
  void _addTextureDetails(Canvas canvas, List<Offset> points, StyleSettings style, double elevation) {
    // Create a bounding rectangle for the feature
    double minX = points.map((p) => p.dx).reduce(math.min);
    double maxX = points.map((p) => p.dx).reduce(math.max);
    double minY = points.map((p) => p.dy).reduce(math.min);
    double maxY = points.map((p) => p.dy).reduce(math.max);
    
    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
    
    // Create a path from screen points
    final path = ui.Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    
    // Clip to feature boundary
    canvas.save();
    canvas.clipPath(path);
    
    // Add texture details based on style type
    switch (style.textureType) {
      case TextureType.forest:
        _addForestTexture(canvas, path, rect, style, elevation);
        break;
      case TextureType.park:
        _addParkTexture(canvas, path, rect, style, elevation);
        break;
      case TextureType.grass:
        _addGrassTexture(canvas, path, rect, style, elevation);
        break;
      case TextureType.simple:
      default:
        // No additional texture
        break;
    }
    
    canvas.restore();
  }
  
  // Add forest texture with trees represented by simple shapes
  void _addForestTexture(Canvas canvas, ui.Path basePath, Rect rect, StyleSettings style, double elevation) {
    // Create tree elements with pseudo-random placement
    final random = math.Random(_seed);
    
    // Calculate tree density based on zoom level
    final double density = math.min(0.0008 * zoomLevel, 0.01);
    final int numTrees = math.max(5, (rect.width * rect.height * density).toInt());
    
    // Calculate tree size based on zoom and tilt
    final double baseSize = math.max(3.0, zoomLevel - 10);
    
    // Draw trees
    for (int i = 0; i < numTrees; i++) {
      // Pseudo-random position within the rectangle
      final x = minmax(rect.left + random.nextDouble() * rect.width, rect.left, rect.right);
      final y = minmax(rect.top + random.nextDouble() * rect.height, rect.top, rect.bottom);
      
      // Vary tree size slightly
      final size = baseSize * (0.8 + random.nextDouble() * 0.4);
      
      // Tree trunk
      final trunkPaint = Paint()
        ..color = Color(0xFF8B5A2B)
        ..style = PaintingStyle.fill;
      
      // Tree canopy
      final canopyPaint = Paint()
        ..color = style.baseColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      
      // Draw a stylized tree
      final trunkRect = Rect.fromCenter(
        center: Offset(x, y + size * 0.4),
        width: size * 0.2,
        height: size * 0.8,
      );
      
      canvas.drawRect(trunkRect, trunkPaint);
      
      // Draw tree canopy as a triangle for a more modern, stylized look
      final canopyPath = ui.Path();
      canopyPath.moveTo(x, y - size * 0.6);
      canopyPath.lineTo(x - size * 0.5, y + size * 0.1);
      canopyPath.lineTo(x + size * 0.5, y + size * 0.1);
      canopyPath.close();
      
      canvas.drawPath(canopyPath, canopyPaint);
    }
  }
  
  // Add park texture with paths and scattered details
  void _addParkTexture(Canvas canvas, ui.Path basePath, Rect rect, StyleSettings style, double elevation) {
    final random = math.Random(_seed);
    
    // Draw paths
    if (rect.width > 50 && rect.height > 50) {
      final pathPaint = Paint()
        ..color = Color(0xFFD2B48C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Add a few curved paths
      for (int i = 0; i < 2; i++) {
        final path = ui.Path();
        
        // Start and end points
        final startX = rect.left + random.nextDouble() * rect.width * 0.3;
        final startY = rect.top + random.nextDouble() * rect.height;
        final endX = rect.right - random.nextDouble() * rect.width * 0.3;
        final endY = rect.top + random.nextDouble() * rect.height;
        
        // Control points for curve
        final ctrlX1 = startX + (endX - startX) * 0.3;
        final ctrlY1 = startY + (random.nextDouble() - 0.5) * rect.height * 0.5;
        final ctrlX2 = startX + (endX - startX) * 0.7;
        final ctrlY2 = endY + (random.nextDouble() - 0.5) * rect.height * 0.5;
        
        path.moveTo(startX, startY);
        path.cubicTo(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
        
        canvas.drawPath(path, pathPaint);
      }
    }
    
    // Add dots representing flowers or benches
    final detailPaint = Paint()
      ..color = Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    
    final double density = math.min(0.0004 * zoomLevel, 0.002);
    final int numDetails = math.max(3, (rect.width * rect.height * density).toInt());
    
    for (int i = 0; i < numDetails; i++) {
      final x = rect.left + random.nextDouble() * rect.width;
      final y = rect.top + random.nextDouble() * rect.height;
      
      // Different sizes for variety
      final size = 1.0 + random.nextDouble() * 2.0;
      
      // Different colors for variety
      final color = [
        Color(0xFFFFF8DC), // Cream for benches
        Color(0xFFFFFF00), // Yellow for flowers
        Color(0xFFFF69B4), // Pink for flowers
      ][random.nextInt(3)];
      
      detailPaint.color = color;
      canvas.drawCircle(Offset(x, y), size, detailPaint);
    }
  }
  
  // Add grass texture with subtle line patterns
  void _addGrassTexture(Canvas canvas, ui.Path basePath, Rect rect, StyleSettings style, double elevation) {
    final random = math.Random(_seed);
    
    // Only add detailed grass texture when zoomed in enough
    if (zoomLevel > 14) {
      final grassPaint = Paint()
        ..color = style.highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      // Calculate grid size based on zoom
      final gridSize = math.max(30, 50 - (zoomLevel - 14) * 5);
      
      // Create grid of grass tufts
      for (double x = rect.left; x < rect.right; x += gridSize) {
        for (double y = rect.top; y < rect.bottom; y += gridSize) {
          // Add some randomness to positions
          final offsetX = x + (random.nextDouble() - 0.5) * gridSize * 0.5;
          final offsetY = y + (random.nextDouble() - 0.5) * gridSize * 0.5;
          
          // Only draw some percentage of the grass tufts
          if (random.nextDouble() > 0.3) {
            // Create grass tuft with 2-3 blades
            final blades = 2 + random.nextInt(2);
            final baseX = offsetX;
            final baseY = offsetY;
            
            for (int i = 0; i < blades; i++) {
              final angle = (random.nextDouble() - 0.5) * math.pi * 0.5;
              final length = 2.0 + random.nextDouble() * 3.0;
              
              final endX = baseX + math.sin(angle) * length;
              final endY = baseY - math.cos(angle) * length;
              
              canvas.drawLine(
                Offset(baseX, baseY),
                Offset(endX, endY),
                grassPaint,
              );
            }
          }
        }
      }
    }
    
    // Add a subtle pattern overlay
    final patternPaint = Paint()
      ..color = style.highlightColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    
    // Draw horizontal lines with slight wave pattern
    for (double y = rect.top; y < rect.bottom; y += 10.0) {
      final wavePath = ui.Path();
      wavePath.moveTo(rect.left, y);
      
      for (double x = rect.left; x <= rect.right; x += 5) {
        final wave = math.sin((x - rect.left) / 30 + (y - rect.top) / 20) * 2.0;
        wavePath.lineTo(x, y + wave);
      }
      
      canvas.drawPath(wavePath, patternPaint);
    }
  }
  
  // Get appropriate style settings based on feature type
  StyleSettings _getStyleForFeature(String type) {
    switch (type) {
      case 'wood':
      case 'forest':
        return StyleSettings(
          baseColor: forestColor,
          highlightColor: forestColor.withGreen(forestColor.green + 20),
          outlineColor: forestColor.withOpacity(0.5),
          textureType: TextureType.forest,
          shouldAddTexture: true,
        );
      
      case 'park':
      case 'garden':
        return StyleSettings(
          baseColor: parkColor,
          highlightColor: parkColor.withGreen(parkColor.green + 20),
          outlineColor: parkColor.withOpacity(0.5),
          textureType: TextureType.park,
          shouldAddTexture: true,
        );
      
      case 'grassland':
      case 'meadow':
      case 'heath':
      case 'scrub':
        return StyleSettings(
          baseColor: grasslandColor,
          highlightColor: grasslandColor.withGreen(grasslandColor.green + 20),
          outlineColor: grasslandColor.withOpacity(0.5),
          textureType: TextureType.grass,
          shouldAddTexture: true,
        );
      
      default:
        // Default style for unknown types
        return StyleSettings(
          baseColor: grasslandColor,
          highlightColor: grasslandColor,
          outlineColor: grasslandColor.withOpacity(0.5),
          textureType: TextureType.simple,
          shouldAddTexture: false,
        );
    }
  }
  
  // Helper for min/max clamping
  double minmax(double value, double min, double max) {
    return math.min(math.max(value, min), max);
  }
  
  /// Calculate zoom factor for scaling elements based on zoom level
  double _getZoomFactor(double zoom) {
    // Enhanced zoom factor calculation for more dramatic 3D effect
    return math.max(0.7, (zoom - 9) / 9); // Scale factor based on zoom with more aggressive scaling
  }
  
  @override
  bool shouldRepaint(LandscapePainter oldDelegate) {
    return oldDelegate.landscapeFeatures != landscapeFeatures ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.parkColor != parkColor ||
           oldDelegate.forestColor != forestColor ||
           oldDelegate.grasslandColor != grasslandColor;
  }
}

// Texture types for different landscape features
enum TextureType {
  simple,
  forest,
  park,
  grass,
}

// Style settings for landscape features
class StyleSettings {
  final Color baseColor;
  final Color highlightColor;
  final Color outlineColor;
  final TextureType textureType;
  final bool shouldAddTexture;
  
  StyleSettings({
    required this.baseColor,
    required this.highlightColor,
    required this.outlineColor,
    required this.textureType,
    required this.shouldAddTexture,
  });
} 