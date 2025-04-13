import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path

import 'osm_data_processor.dart';

/// A custom layer to render OpenStreetMap parks and vegetation in 2.5D
class OSMParksLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final bool isMapMoving;
  final Color parkColor;
  final Color forestColor;
  
  const OSMParksLayer({
    Key? key,
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
    this.isMapMoving = false,
    this.parkColor = const Color(0xFF43A047),  // Green by default
    this.forestColor = const Color(0xFF2E7D32), // Darker green for forests
  }) : super(key: key);

  @override
  State<OSMParksLayer> createState() => _OSMParksLayerState();
}

class _OSMParksLayerState extends State<OSMParksLayer> with SingleTickerProviderStateMixin {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  Map<String, List<Map<String, dynamic>>> _parksData = {};
  bool _isLoading = true;
  bool _needsRefresh = true;
  String _lastBoundsKey = "";
  
  // Animation controller for subtle wind effect
  late AnimationController _animationController;
  late Animation<double> _windAnimation;
  
  // Enhanced park type colors with more vibrant and complementary options
  final Map<String, Color> _parkTypeColors = {
    'park': const Color(0xFF43A047).withOpacity(0.65),     // Medium green for parks
    'forest': const Color(0xFF2E7D32).withOpacity(0.75),   // Darker green for forests
    'grass': const Color(0xFF66BB6A).withOpacity(0.55),    // Lighter green for grass
    'meadow': const Color(0xFF81C784).withOpacity(0.6),    // Light green for meadows
    'garden': const Color(0xFF4CAF50).withOpacity(0.7),    // Standard green for gardens
    'wood': const Color(0xFF33691E).withOpacity(0.75),     // Dark green for woods
    // Additional park types with beautiful colors
    'nature_reserve': const Color(0xFF1B5E20).withOpacity(0.7),  // Deep green
    'recreation_ground': const Color(0xFF7CB342).withOpacity(0.65), // Lime green
    'playground': const Color(0xFF8BC34A).withOpacity(0.7),     // Light green
    'golf_course': const Color(0xFFA5D6A7).withOpacity(0.7),    // Pastel green
    'orchard': const Color(0xFFAED581).withOpacity(0.7),        // Yellowish green
    'vineyard': const Color(0xFFCDDC39).withOpacity(0.65),      // Lime
    'cemetery': const Color(0xFF558B2F).withOpacity(0.6),       // Olive green
    'farmland': const Color(0xFFDAD785).withOpacity(0.55),      // Wheat color
  };
  
  // Seasonal color variations that could be switched based on current season
  final Map<String, Map<String, Color>> _seasonalColors = {
    'spring': {
      'park': const Color(0xFF66BB6A).withOpacity(0.65),      // Brighter spring green
      'forest': const Color(0xFF388E3C).withOpacity(0.7),     // Fresh forest green
      'meadow': const Color(0xFF9CCC65).withOpacity(0.6),     // Spring meadow with flowers
    },
    'summer': {
      'park': const Color(0xFF43A047).withOpacity(0.65),      // Summer green
      'forest': const Color(0xFF2E7D32).withOpacity(0.75),    // Deep summer forest green
      'meadow': const Color(0xFF81C784).withOpacity(0.6),     // Summer meadow
    },
    'autumn': {
      'park': const Color(0xFFAFB42B).withOpacity(0.65),      // Yellowish autumn
      'forest': const Color(0xFFFF8F00).withOpacity(0.7),     // Orange autumn forest
      'meadow': const Color(0xFFFFEB3B).withOpacity(0.5),     // Yellow autumn meadow
    },
    'winter': {
      'park': const Color(0xFFCFD8DC).withOpacity(0.5),       // Light grayish winter
      'forest': const Color(0xFF546E7A).withOpacity(0.6),     // Dark winter forest
      'meadow': const Color(0xFFECEFF1).withOpacity(0.5),     // White winter meadow
    },
  };
  
  // Time of day colors that could be used based on current time
  final Map<String, Map<String, Color>> _timeOfDayColors = {
    'morning': {
      'park': const Color(0xFF66BB6A).withOpacity(0.7),       // Morning dew green
      'forest': const Color(0xFF2E7D32).withOpacity(0.7),     // Morning forest
    },
    'noon': {
      'park': const Color(0xFF43A047).withOpacity(0.65),      // Bright noon green
      'forest': const Color(0xFF1B5E20).withOpacity(0.7),     // Dark noon forest
    },
    'evening': {
      'park': const Color(0xFF558B2F).withOpacity(0.6),       // Evening green with orange tint
      'forest': const Color(0xFF33691E).withOpacity(0.7),     // Evening forest
    },
    'night': {
      'park': const Color(0xFF1B5E20).withOpacity(0.5),       // Dark night park
      'forest': const Color(0xFF0A3D12).withOpacity(0.6),     // Night forest
    },
  };
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for wind effect
    _animationController = AnimationController(
      duration: const Duration(seconds: 3), 
      vsync: this,
    );
    
    _windAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Loop the animation for continuous effect
    _animationController.repeat(reverse: true);
    
    _fetchParksData();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OSMParksLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Get a key to identify current map bounds
    final newBoundsKey = _getBoundsKey();
    
    // Fetch new data when map bounds change significantly or zoom changes
    if (oldWidget.visibleBounds != widget.visibleBounds || 
        oldWidget.zoomLevel != widget.zoomLevel ||
        _lastBoundsKey != newBoundsKey) {
      
      _needsRefresh = true;
      
      // If map is actively moving, delay the fetch to avoid too many API calls
      if (widget.isMapMoving) {
        _delayedFetch();
      } else {
        _fetchParksData();
      }
    }
    
    // Update colors if they changed
    if (oldWidget.parkColor != widget.parkColor || 
        oldWidget.forestColor != widget.forestColor) {
      _updateParkColors();
    }
  }
  
  // Update park colors when theme colors change, with more vibrant options
  void _updateParkColors() {
    setState(() {
      _parkTypeColors['park'] = widget.parkColor.withOpacity(0.65);
      _parkTypeColors['garden'] = Color.alphaBlend(widget.parkColor.withOpacity(0.1), const Color(0xFF66BB6A)).withOpacity(0.7);
      _parkTypeColors['grass'] = Color.alphaBlend(widget.parkColor.withOpacity(0.05), const Color(0xFF8BC34A)).withOpacity(0.55);
      _parkTypeColors['meadow'] = Color.alphaBlend(widget.parkColor.withOpacity(0.05), const Color(0xFF9CCC65)).withOpacity(0.6);
      
      _parkTypeColors['forest'] = widget.forestColor.withOpacity(0.75);
      _parkTypeColors['wood'] = Color.alphaBlend(widget.forestColor.withOpacity(0.1), const Color(0xFF33691E)).withOpacity(0.75);
      _parkTypeColors['nature_reserve'] = Color.alphaBlend(widget.forestColor.withOpacity(0.15), const Color(0xFF1B5E20)).withOpacity(0.7);
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
        _fetchParksData();
      }
    });
  }
  
  void _fetchParksData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Update bounds key
    _lastBoundsKey = _getBoundsKey();
    
    // Use the map bounds to fetch data
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final parksData = await _dataProcessor.fetchParksData(southwest, northeast);
    
    if (mounted) {
      setState(() {
        _parksData = parksData;
        _isLoading = false;
        _needsRefresh = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while loading or if data is empty
    if (_isLoading || _parksData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _windAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: OSMParksPainter(
            parks: _parksData['parks'] ?? [],
            trees: _parksData['trees'] ?? [],
            parkColors: _parkTypeColors,
            tiltFactor: widget.tiltFactor,
            zoomLevel: widget.zoomLevel,
            mapBounds: widget.visibleBounds,
            windFactor: _windAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter to render parks and vegetation in 2.5D
class OSMParksPainter extends CustomPainter {
  final List<dynamic> parks;
  final List<dynamic> trees;
  final Map<String, Color> parkColors;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds mapBounds;
  final double windFactor;
  
  OSMParksPainter({
    required this.parks,
    required this.trees,
    required this.parkColors,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.mapBounds,
    required this.windFactor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // First draw parks (areas)
    for (final park in parks) {
      final List<LatLng> points = park['points'] as List<LatLng>;
      if (points.length < 3) continue; // Need at least 3 points for an area
      
      final String parkType = park['type'] as String;
      final double elevation = (park['elevation'] as double) * tiltFactor;
      
      // Get color for this park type or use default
      final Color parkColor = parkColors[parkType] ?? 
                              parkColors['park'] ?? 
                              const Color(0xFF4CAF50).withOpacity(0.5);
      
      // Convert LatLng points to screen coordinates
      final List<Offset> screenPoints = points.map((latLng) {
        // Map from LatLng to screen coordinates
        final double x = (latLng.longitude - sw.longitude) / mapWidth * size.width;
        final double y = (1 - (latLng.latitude - sw.latitude) / mapHeight) * size.height;
        return Offset(x, y - elevation); // Apply slight elevation for 2.5D effect
      }).toList();
      
      // Draw the park area
      _drawParkArea(canvas, screenPoints, parkColor, parkType);
      
      // If zoom is high enough, add detailed vegetation patterns
      if (zoomLevel >= 15.0) {
        _addParkDetails(canvas, screenPoints, parkColor, parkType);
      }
    }
    
    // Then draw individual trees if zoom level is high enough
    if (zoomLevel >= 16.0 && tiltFactor > 0.1) {
      _drawTrees(canvas, trees, size);
    }
  }
  
  /// Draw a park or forest area
  void _drawParkArea(Canvas canvas, List<Offset> points, Color color, String parkType) {
    // Create path for the park area
    final Path parkPath = Path();
    parkPath.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      parkPath.lineTo(points[i].dx, points[i].dy);
    }
    
    parkPath.close(); // Close the path to form an area
    
    // Draw park area fill
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    
    canvas.drawPath(parkPath, fillPaint);
    
    // Draw a very subtle border for definition
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withAlpha(150);
    
    canvas.drawPath(parkPath, borderPaint);
  }
  
  /// Add detailed vegetation patterns to parks
  void _addParkDetails(Canvas canvas, List<Offset> points, Color baseColor, String parkType) {
    // Skip for certain types or if too few points
    if (points.length < 5) return;
    
    // Calculate a simple bounding box for the park
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    
    for (final point in points) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }
    
    // Create a path to clip detail rendering to the park area
    final Path clipPath = Path();
    clipPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      clipPath.lineTo(points[i].dx, points[i].dy);
    }
    clipPath.close();
    
    // Apply clip to limit drawing to park area
    canvas.save();
    canvas.clipPath(clipPath);
    
    // Choose pattern based on park type
    if (parkType == 'forest' || parkType == 'wood') {
      _addForestPattern(canvas, Rect.fromLTRB(minX, minY, maxX, maxY), baseColor);
    } else if (parkType == 'park' || parkType == 'garden') {
      _addParkPattern(canvas, Rect.fromLTRB(minX, minY, maxX, maxY), baseColor);
    } else if (parkType == 'grass' || parkType == 'meadow') {
      _addGrassPattern(canvas, Rect.fromLTRB(minX, minY, maxX, maxY), baseColor);
    }
    
    canvas.restore();
  }
  
  /// Add a forest-specific pattern
  void _addForestPattern(Canvas canvas, Rect bounds, Color baseColor) {
    final random = math.Random(42); // Fixed seed for consistent pattern
    final int treeDensity = 20 + (zoomLevel ~/ 2); // Increase density with zoom
    
    final double spacing = math.min(bounds.width, bounds.height) / math.sqrt(treeDensity);
    
    // Enhanced forest pattern with more varied tree colors
    final List<Color> treeColors = [
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness + 0.1).clamp(0.0, 1.0)).toColor(),
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness + 0.05).clamp(0.0, 1.0)).toColor(),
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness - 0.05).clamp(0.0, 1.0)).toColor(),
    ];
    
    // Draw small tree symbols
    for (int i = 0; i < treeDensity; i++) {
      final double x = bounds.left + random.nextDouble() * bounds.width;
      final double y = bounds.top + random.nextDouble() * bounds.height;
      
      // Draw simple tree dot with varied colors
      final Paint treePaint = Paint()
        ..color = treeColors[random.nextInt(treeColors.length)]
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 1.5, treePaint);
    }
  }
  
  /// Add a park-specific pattern
  void _addParkPattern(Canvas canvas, Rect bounds, Color baseColor) {
    final random = math.Random(24); // Different seed from forest
    
    // Create a grid pattern
    final gridSize = 20.0;
    final Paint linePaint = Paint()
      ..color = baseColor.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // Enhanced colors for park details
    final List<Color> flowerColors = [
      const Color(0xFFFFF176).withOpacity(0.7),  // Yellow flowers
      const Color(0xFFFFCDD2).withOpacity(0.6),  // Pink flowers
      const Color(0xFFB3E5FC).withOpacity(0.6),  // Blue flowers
      const Color(0xFFE1BEE7).withOpacity(0.6),  // Purple flowers
      const Color(0xFFFFCCBC).withOpacity(0.6),  // Orange flowers
    ];
    
    // Draw more interesting scattered dots for flowers or shrubs
    for (int i = 0; i < 40; i++) {  // Increased from 30 to 40 for more flowers
      final double x = bounds.left + random.nextDouble() * bounds.width;
      final double y = bounds.top + random.nextDouble() * bounds.height;
      
      // Random dot color - higher chance of flowers for more color
      final Paint dotPaint = Paint()
        ..color = random.nextDouble() > 0.6  // 40% chance of flower vs 30% before
            ? flowerColors[random.nextInt(flowerColors.length)]
            : HSLColor.fromColor(baseColor).withLightness(
                (HSLColor.fromColor(baseColor).lightness + 0.15).clamp(0.0, 1.0)).toColor()
        ..style = PaintingStyle.fill;
      
      // Small dots for detailed park features
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 1.2 + 0.5, dotPaint);
    }
  }
  
  /// Add a grass-specific pattern with more varied grass
  void _addGrassPattern(Canvas canvas, Rect bounds, Color baseColor) {
    final random = math.Random(36); // Different seed again
    
    // More varied grass shades
    final List<Color> grassShades = [
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness + 0.15).clamp(0.0, 1.0)).toColor().withOpacity(0.3),
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness + 0.05).clamp(0.0, 1.0)).toColor().withOpacity(0.3),
      HSLColor.fromColor(baseColor).withLightness(
          (HSLColor.fromColor(baseColor).lightness).clamp(0.0, 1.0)).toColor().withOpacity(0.3),
    ];
    
    // Draw more grass-like lines with varied colors and lengths
    for (int i = 0; i < 60; i++) {  // Increased from 40 to 60 for more density
      final double x = bounds.left + random.nextDouble() * bounds.width;
      final double y = bounds.top + random.nextDouble() * bounds.height;
      
      final Paint grassPaint = Paint()
        ..color = grassShades[random.nextInt(grassShades.length)]
        ..strokeWidth = 0.5 + random.nextDouble() * 0.4  // More varied thickness
        ..style = PaintingStyle.stroke;
      
      // Simple grass blade with more varied angles and lengths
      final double angle = random.nextDouble() * math.pi;
      final double length = 2.0 + random.nextDouble() * 4.0;  // Longer grass blades
      
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * length, y + math.sin(angle) * length),
        grassPaint
      );
    }
  }
  
  /// Draw individual trees (for high zoom levels)
  void _drawTrees(Canvas canvas, List<dynamic> trees, Size size) {
    // Skip if too few trees or zoom level too low
    if (trees.isEmpty || zoomLevel < 16.0) return;
    
    // Limit number of trees to draw for performance
    final maxTrees = math.min(trees.length, 100);
    final treesToDraw = trees.take(maxTrees).toList();
    
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // Draw each tree
    for (final tree in treesToDraw) {
      final LatLng location = tree['location'] as LatLng;
      
      // Convert LatLng to screen coordinates
      final double x = (location.longitude - sw.longitude) / mapWidth * size.width;
      final double y = (1 - (location.latitude - sw.latitude) / mapHeight) * size.height;
      
      // Apply wind effect to tree position
      final double windOffset = windFactor * 3.0;
      
      // Draw simple tree with trunk and foliage
      _drawTreeSymbol(canvas, Offset(x + windOffset, y), 5.0 * math.min(1.0, (zoomLevel - 15.0) / 3.0));
    }
  }
  
  /// Draw a simple tree symbol with more detail
  void _drawTreeSymbol(Canvas canvas, Offset position, double size) {
    // Tree trunk (richer brown)
    final Paint trunkPaint = Paint()
      ..color = const Color(0xFF6D4C41)  // Richer brown color
      ..style = PaintingStyle.fill;
    
    // Tree foliage with more varied greens
    final List<Color> foliageColors = [
      const Color(0xFF388E3C),  // Standard green
      const Color(0xFF2E7D32),  // Darker green
      const Color(0xFF43A047),  // Lighter green
    ];
    
    // Randomly select a foliage color for variety
    final random = math.Random(position.dx.toInt() * 1000 + position.dy.toInt());
    final Paint foliagePaint = Paint()
      ..color = foliageColors[random.nextInt(foliageColors.length)]
      ..style = PaintingStyle.fill;
    
    // Draw trunk
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy + size * 0.5),
        width: size * 0.3,
        height: size * 0.7
      ),
      trunkPaint
    );
    
    // Draw foliage (more interesting than just a circle)
    if (size > 3.0) {
      // Draw a more detailed tree crown with multiple circles for larger trees
      canvas.drawCircle(
        Offset(position.dx - size * 0.2, position.dy - size * 0.3),
        size * 0.6,
        foliagePaint
      );
      canvas.drawCircle(
        Offset(position.dx + size * 0.2, position.dy - size * 0.3),
        size * 0.6,
        foliagePaint
      );
      canvas.drawCircle(
        Offset(position.dx, position.dy - size * 0.6),
        size * 0.6,
        foliagePaint
      );
    } else {
      // Simpler circle for smaller trees
      canvas.drawCircle(
        Offset(position.dx, position.dy - size * 0.2),
        size * 0.8,
        foliagePaint
      );
    }
  }
  
  @override
  bool shouldRepaint(OSMParksPainter oldDelegate) {
    return oldDelegate.parks != parks ||
           oldDelegate.trees != trees ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.mapBounds != mapBounds ||
           oldDelegate.windFactor != windFactor;
  }
} 