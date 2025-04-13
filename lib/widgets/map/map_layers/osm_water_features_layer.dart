import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path

import 'osm_data_processor.dart';

/// A custom layer to render OpenStreetMap water features in 2.5D
class OSMWaterFeaturesLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final bool isMapMoving;
  final Color waterColor;
  final Color waterOutlineColor;
  
  const OSMWaterFeaturesLayer({
    Key? key,
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
    this.isMapMoving = false,
    this.waterColor = const Color(0xFF1976D2), // Primary blue by default
    this.waterOutlineColor = const Color(0xFF0D47A1), // Darker blue for outlines
  }) : super(key: key);

  @override
  State<OSMWaterFeaturesLayer> createState() => _OSMWaterFeaturesLayerState();
}

class _OSMWaterFeaturesLayerState extends State<OSMWaterFeaturesLayer> with SingleTickerProviderStateMixin {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _waterFeatures = [];
  bool _isLoading = true;
  bool _needsRefresh = true;
  String _lastBoundsKey = "";
  
  // Animation controller for water ripple effect
  late AnimationController _animationController;
  late Animation<double> _rippleAnimation;
  
  // Enhanced water type colors with vibrant blues and complementary tones
  final Map<String, Color> _waterTypeColors = {
    'river': const Color(0xFF1976D2).withOpacity(0.75),    // Rich blue for rivers
    'stream': const Color(0xFF4FC3F7).withOpacity(0.65),   // Light blue for streams
    'canal': const Color(0xFF0288D1).withOpacity(0.7),     // Medium blue for canals
    'lake': const Color(0xFF0277BD).withOpacity(0.65),     // Deep blue for lakes
    'reservoir': const Color(0xFF01579B).withOpacity(0.7), // Deeper blue for reservoirs
    'pond': const Color(0xFF4DD0E1).withOpacity(0.65),     // Cyan-blue for ponds
    'water': const Color(0xFF0288D1).withOpacity(0.7),     // Generic water
    'coastline': const Color(0xFF039BE5).withOpacity(0.65), // Bright blue for coastlines
    'drain': const Color(0xFF80DEEA).withOpacity(0.5),     // Very light cyan for drains
    'ditch': const Color(0xFF80DEEA).withOpacity(0.45),    // Very light cyan for ditches
  };
  
  // Time of day water colors for different lighting conditions
  final Map<String, Map<String, Color>> _timeOfDayWaterColors = {
    'morning': {
      'river': const Color(0xFF64B5F6).withOpacity(0.7),    // Morning light blue
      'lake': const Color(0xFF42A5F5).withOpacity(0.65),    // Morning lake blue
    },
    'noon': {
      'river': const Color(0xFF1976D2).withOpacity(0.75),   // Noon vibrant blue
      'lake': const Color(0xFF0277BD).withOpacity(0.65),    // Noon deep blue
    },
    'evening': {
      'river': const Color(0xFF0D47A1).withOpacity(0.65),   // Evening darker blue with purple tint
      'lake': const Color(0xFF1A237E).withOpacity(0.6),     // Evening deep blue-purple
    },
    'night': {
      'river': const Color(0xFF1A237E).withOpacity(0.5),    // Night deep blue
      'lake': const Color(0xFF0D47A1).withOpacity(0.45),    // Night blue
    },
  };

  // Special themed color schemes that can be activated
  final Map<String, Map<String, Color>> _themeWaterColors = {
    'default': {
      'river': const Color(0xFF1976D2).withOpacity(0.75),
      'lake': const Color(0xFF0277BD).withOpacity(0.65),
    },
    'pink': {
      'river': const Color(0xFFEC407A).withOpacity(0.65),   // Pink water for special themes
      'lake': const Color(0xFFD81B60).withOpacity(0.55),    // Deeper pink for lakes
      'stream': const Color(0xFFF48FB1).withOpacity(0.6),   // Light pink for streams
      'coastline': const Color(0xFFE91E63).withOpacity(0.5), // Medium pink for coastlines
    },
    'tropical': {
      'river': const Color(0xFF00BCD4).withOpacity(0.7),    // Turquoise water
      'lake': const Color(0xFF00ACC1).withOpacity(0.65),    // Deeper turquoise for lakes
      'coastline': const Color(0xFF26C6DA).withOpacity(0.6), // Bright turquoise for coastline
    },
  };
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for ripple effect
    _animationController = AnimationController(
      duration: const Duration(seconds: 4), // Slow ripple animation
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Loop the animation for continuous ripple
    _animationController.repeat(reverse: true);
    
    _fetchWaterFeatures();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OSMWaterFeaturesLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Get a key to identify current map bounds
    final newBoundsKey = _getBoundsKey();
    
    // Fetch new water data when map bounds change significantly or zoom changes
    if (oldWidget.visibleBounds != widget.visibleBounds || 
        oldWidget.zoomLevel != widget.zoomLevel ||
        _lastBoundsKey != newBoundsKey) {
      
      _needsRefresh = true;
      
      // If map is actively moving, delay the fetch to avoid too many API calls
      if (widget.isMapMoving) {
        _delayedFetch();
      } else {
        _fetchWaterFeatures();
      }
    }
    
    // Update colors if they changed
    if (oldWidget.waterColor != widget.waterColor) {
      _updateWaterColors();
    }
  }
  
  // Update water colors when theme color changes with enhanced color options
  void _updateWaterColors() {
    setState(() {
      // Base color for water features - could blend with pink tones from app theme
      final baseBlueColor = widget.waterColor;
      final pinkTint = const Color(0xFFE91E63).withOpacity(0.2); // Subtle pink tint
      
      // Advanced color calculations for different water types
      _waterTypeColors['river'] = Color.alphaBlend(pinkTint.withOpacity(0.1), baseBlueColor).withOpacity(0.75);
      _waterTypeColors['stream'] = Color.alphaBlend(pinkTint.withOpacity(0.15), const Color(0xFF4FC3F7)).withOpacity(0.65);
      _waterTypeColors['canal'] = Color.alphaBlend(pinkTint.withOpacity(0.05), baseBlueColor).withOpacity(0.7);
      _waterTypeColors['lake'] = Color.alphaBlend(pinkTint.withOpacity(0.1), const Color(0xFF0277BD)).withOpacity(0.65);
      _waterTypeColors['reservoir'] = Color.alphaBlend(pinkTint.withOpacity(0.05), const Color(0xFF01579B)).withOpacity(0.7);
      _waterTypeColors['pond'] = Color.alphaBlend(pinkTint.withOpacity(0.2), const Color(0xFF4DD0E1)).withOpacity(0.65);
      _waterTypeColors['water'] = Color.alphaBlend(pinkTint.withOpacity(0.1), baseBlueColor).withOpacity(0.7);
      _waterTypeColors['coastline'] = Color.alphaBlend(pinkTint.withOpacity(0.15), const Color(0xFF039BE5)).withOpacity(0.65);
      _waterTypeColors['drain'] = Color.alphaBlend(pinkTint.withOpacity(0.2), const Color(0xFF80DEEA)).withOpacity(0.5);
      _waterTypeColors['ditch'] = Color.alphaBlend(pinkTint.withOpacity(0.2), const Color(0xFF80DEEA)).withOpacity(0.45);
    });
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
        _fetchWaterFeatures();
      }
    });
  }
  
  void _fetchWaterFeatures() async {
    setState(() {
      _isLoading = true;
    });
    
    // Update bounds key
    _lastBoundsKey = _getBoundsKey();
    
    // Use the map bounds to fetch water features
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final waterFeatures = await _dataProcessor.fetchWaterFeaturesData(southwest, northeast);
    
    if (mounted) {
      setState(() {
        _waterFeatures = waterFeatures;
        _isLoading = false;
        _needsRefresh = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while loading or if water features list is empty
    if (_isLoading || _waterFeatures.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _rippleAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: OSMWaterFeaturesPainter(
            waterFeatures: _waterFeatures,
            waterColors: _waterTypeColors,
            waterOutlineColor: widget.waterOutlineColor,
            tiltFactor: widget.tiltFactor,
            zoomLevel: widget.zoomLevel,
            mapBounds: widget.visibleBounds,
            rippleValue: _rippleAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter to render water features in 2.5D
class OSMWaterFeaturesPainter extends CustomPainter {
  final List<Map<String, dynamic>> waterFeatures;
  final Map<String, Color> waterColors;
  final Color waterOutlineColor;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds mapBounds;
  final double rippleValue;
  
  OSMWaterFeaturesPainter({
    required this.waterFeatures,
    required this.waterColors,
    required this.waterOutlineColor,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.mapBounds,
    required this.rippleValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Skip painting with very minor tilt
    if (tiltFactor < 0.05) return;
    
    // First, sort the water features by type for proper rendering order
    // Draw larger bodies like lakes and rivers first, then streams and smaller features
    final sortedWaterFeatures = _sortWaterFeaturesByType(waterFeatures);
    
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // Draw each water feature
    for (final feature in sortedWaterFeatures) {
      final List<LatLng> points = feature['points'] as List<LatLng>;
      if (points.isEmpty) continue; // Skip invalid features
      
      final String waterType = feature['type'] as String;
      final double width = feature['width'] as double;
      
      // Get color for this water type or use default
      final Color waterColor = waterColors[waterType] ?? waterColors['water'] ?? const Color(0xFF1976D2).withOpacity(0.6);
      
      // Apply ripple effect to color
      final Color rippleColor = _applyRippleToColor(waterColor, rippleValue);
      
      // Convert LatLng points to screen coordinates
      final List<Offset> screenPoints = points.map((latLng) {
        // Map from LatLng to screen coordinates
        final double x = (latLng.longitude - sw.longitude) / mapWidth * size.width;
        final double y = (1 - (latLng.latitude - sw.latitude) / mapHeight) * size.height;
        return Offset(x, y); // Water is flat, no elevation
      }).toList();
      
      // Distinguish between area water features and linear water features
      final bool isAreaFeature = _isAreaWaterFeature(waterType);
      
      if (isAreaFeature) {
        // Draw water areas (lakes, ponds, reservoirs, etc.)
        _drawWaterArea(canvas, screenPoints, rippleColor, waterOutlineColor);
      } else {
        // Draw linear water features (rivers, streams, canals, etc.)
        _drawWaterWay(canvas, screenPoints, width * _getZoomFactor(zoomLevel), rippleColor, waterOutlineColor);
      }
    }
  }
  
  /// Sort water features by type for proper layering
  List<Map<String, dynamic>> _sortWaterFeaturesByType(List<Map<String, dynamic>> features) {
    // Define water feature type ranking (larger/wider features first)
    const Map<String, int> importance = {
      'water': 10,       // Generic water bodies first
      'lake': 9,
      'reservoir': 8,
      'pond': 7,
      'coastline': 6,
      'river': 5,
      'canal': 4,
      'stream': 3,
      'drain': 2,
      'ditch': 1,
    };
    
    // Sort by importance (higher importance first)
    return List<Map<String, dynamic>>.from(features)
      ..sort((a, b) {
        final typeA = a['type'] as String;
        final typeB = b['type'] as String;
        
        final importanceA = importance[typeA] ?? 0;
        final importanceB = importance[typeB] ?? 0;
        
        return importanceB.compareTo(importanceA); // Notice reversed order: higher first
      });
  }
  
  /// Apply ripple effect to water color with enhanced visual effect
  Color _applyRippleToColor(Color baseColor, double rippleValue) {
    // More dynamic ripple effect with enhanced color variation
    final HSLColor hslColor = HSLColor.fromColor(baseColor);
    final rippleFactor = 0.08 + (rippleValue * 0.12); // Increased wave effect
    
    // Add a subtle pink cast to the highlights for app theme harmony
    final pinkHighlight = rippleValue > 0.7 ? 0.05 : 0.0;
    
    return hslColor
        .withSaturation((hslColor.saturation + rippleFactor).clamp(0.0, 1.0))
        .withLightness((hslColor.lightness + rippleFactor).clamp(0.0, 1.0))
        .withHue((hslColor.hue + (pinkHighlight * 30)).clamp(0.0, 360.0)) // Slight hue shift toward pink
        .toColor();
  }
  
  /// Check if water feature is an area (not a linear feature)
  bool _isAreaWaterFeature(String waterType) {
    return ['lake', 'pond', 'reservoir', 'water'].contains(waterType);
  }
  
  /// Calculate zoom factor for scaling elements based on zoom level
  double _getZoomFactor(double zoom) {
    return math.max(0.5, (zoom - 10) / 10); // Scale factor based on zoom
  }
  
  /// Draw a water area (lake, pond, reservoir, etc.)
  void _drawWaterArea(Canvas canvas, List<Offset> points, Color color, Color outlineColor) {
    if (points.length < 3) return; // Need at least 3 points for an area
    
    // Create path for the water area
    final Path waterPath = Path();
    waterPath.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      waterPath.lineTo(points[i].dx, points[i].dy);
    }
    
    waterPath.close(); // Close the path to form an area
    
    // Draw water area fill
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    
    canvas.drawPath(waterPath, fillPaint);
    
    // Draw the outline with a subtle border
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = outlineColor.withOpacity(0.4);
    
    canvas.drawPath(waterPath, outlinePaint);
  }
  
  /// Draw a water way (river, stream, canal, etc.)
  void _drawWaterWay(Canvas canvas, List<Offset> points, double width, Color color, Color outlineColor) {
    if (points.length < 2) return; // Need at least 2 points for a line
    
    // Create path for the water way
    final Path waterPath = Path();
    waterPath.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      waterPath.lineTo(points[i].dx, points[i].dy);
    }
    
    // Draw the water way with an outline for definition
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = outlineColor.withOpacity(0.3);
    
    canvas.drawPath(waterPath, outlinePaint);
    
    // Draw the actual water
    final Paint waterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    
    canvas.drawPath(waterPath, waterPaint);
    
    // Add details to water ways like flow lines with enhanced visualization
    _addWaterWayDetails(canvas, points, width, color);
  }
  
  /// Add details to water ways like flow lines with enhanced visualization
  void _addWaterWayDetails(Canvas canvas, List<Offset> points, double width, Color color) {
    if (points.length < 4) return; // Need more points for details
    
    // Create a detail path with lighter color and enhanced visualization
    final Path detailPath = Path();
    final Path highlightPath = Path(); // New path for subtle highlights
    
    // Enhanced colors for water details
    final detailColor = color.withOpacity(0.35);
    final highlightColor = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness + 0.2).clamp(0.0, 1.0))
        .toColor()
        .withOpacity(0.25);
    
    // Use more varied point selection for natural-looking flow lines
    for (int i = 1; i < points.length - 2; i += 2) {
      // Create a smaller curve inside the river
      final Offset p1 = points[i];
      final Offset p2 = points[i+1];
      
      detailPath.moveTo(p1.dx, p1.dy);
      detailPath.lineTo(p2.dx, p2.dy);
      
      // Add occasional highlight lines for sparkle effect
      if (i % 4 == 0) {
        highlightPath.moveTo(p1.dx + width * 0.1, p1.dy - width * 0.1);
        highlightPath.lineTo(p2.dx + width * 0.1, p2.dy - width * 0.1);
      }
    }
    
    // Draw flow lines with subtle, lighter color
    final Paint detailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.3
      ..strokeCap = StrokeCap.round
      ..color = detailColor;
    
    canvas.drawPath(detailPath, detailPaint);
    
    // Draw highlight lines for sparkle effect
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.15
      ..strokeCap = StrokeCap.round
      ..color = highlightColor;
    
    canvas.drawPath(highlightPath, highlightPaint);
    
    // Add occasional ripple circles for larger water bodies
    if (width > 8.0 && zoomLevel >= 16.0) {
      _addWaterRipples(canvas, points, width, color);
    }
  }
  
  /// Add subtle ripple circles to larger water bodies
  void _addWaterRipples(Canvas canvas, List<Offset> points, double width, Color color) {
    final random = math.Random(42); // Fixed seed for consistent pattern
    final rippleCount = math.min(points.length ~/ 8, 5); // Limit the number of ripples
    
    // Create a subtle ripple effect with concentric circles
    for (int i = 0; i < rippleCount; i++) {
      final index = (points.length ~/ rippleCount) * i + (points.length ~/ (rippleCount * 2));
      if (index >= points.length) continue;
      
      final Offset center = points[index];
      final rippleSize = width * (0.8 + random.nextDouble() * 0.4);
      
      // Create base ripple paint
      final Color rippleColor = HSLColor.fromColor(color)
          .withLightness((HSLColor.fromColor(color).lightness + 0.2).clamp(0.0, 1.0))
          .toColor()
          .withOpacity(0.2 + (rippleValue * 0.2));
      
      // Draw the ripple circle with first paint
      final Paint ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = rippleColor;
      
      // Create a second paint for the inner circle
      final Paint innerRipplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = rippleColor;
      
      // Draw concentric circles for ripple effect
      canvas.drawCircle(center, rippleSize * (0.5 + rippleValue * 0.5), ripplePaint);
      canvas.drawCircle(center, rippleSize * (0.3 + rippleValue * 0.5), innerRipplePaint);
    }
  }
  
  @override
  bool shouldRepaint(OSMWaterFeaturesPainter oldDelegate) {
    return oldDelegate.waterFeatures != waterFeatures ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.mapBounds != mapBounds ||
           oldDelegate.rippleValue != rippleValue;
  }
} 