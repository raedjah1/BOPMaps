import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path
import 'package:flutter/foundation.dart';

import 'osm_data_processor.dart';
import '../map_styles.dart';

/// A custom layer to render OpenStreetMap buildings in 2.5D
class OSMBuildingsLayer extends StatefulWidget {
  final Color buildingBaseColor;
  final Color buildingTopColor;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  
  const OSMBuildingsLayer({
    Key? key,
    this.buildingBaseColor = MapStyles.buildingBaseColor,
    this.buildingTopColor = MapStyles.buildingTopColor,
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
  bool _needsRefresh = true;
  String _lastBoundsKey = "";
  
  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }
  
  @override
  void didUpdateWidget(OSMBuildingsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Calculate a key to identify the current visible bounds (with reduced precision)
    final newBoundsKey = _getBoundsKey();
    
    // Only fetch new buildings when zoom level changes significantly or bounds change
    if (oldWidget.zoomLevel != widget.zoomLevel || _lastBoundsKey != newBoundsKey) {
      _needsRefresh = true;
      
      // Immediate refresh for significant zoom changes, delayed for others
      if ((oldWidget.zoomLevel - widget.zoomLevel).abs() > 0.5) {
        _fetchBuildings();
      } else {
        _delayedFetch();
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
        _fetchBuildings();
      }
    });
  }
  
  void _fetchBuildings() async {
    // Skip fetching if too zoomed out (below zoom threshold)
    if (widget.zoomLevel < 13.0) {
      if (mounted) {
        setState(() {
          _buildings = [];
          _isLoading = false;
          _needsRefresh = false;
        });
      }
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // Update bounds key
    _lastBoundsKey = _getBoundsKey();
    
    // Use the map bounds to fetch buildings
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    final buildings = await _dataProcessor.fetchBuildingData(southwest, northeast);
    
    if (mounted) {
      // Apply optimizations based on zoom level
      List<Map<String, dynamic>> optimizedBuildings = _optimizeBuildings(buildings);
      
      setState(() {
        _buildings = optimizedBuildings;
        _isLoading = false;
        _needsRefresh = false;
      });
    }
  }
  
  // Optimize buildings for rendering based on zoom level
  List<Map<String, dynamic>> _optimizeBuildings(List<Map<String, dynamic>> buildings) {
    if (buildings.isEmpty) return [];
    
    // At lower zoom levels, limit the number of buildings to render
    if (widget.zoomLevel < MapStyles.simplifyBuildingsBeforeZoom) {
      // Sort buildings by height/size (keep the most notable ones)
      buildings.sort((a, b) => (b['height'] as double).compareTo(a['height'] as double));
      
      // Further limit buildings at very low zoom
      final int maxBuildings = widget.zoomLevel < 15 
          ? MapStyles.maxBuildingsPerTile 
          : MapStyles.maxBuildingsPerTile * 2;
      
      // Take only the first N buildings
      if (buildings.length > maxBuildings) {
        buildings = buildings.sublist(0, maxBuildings);
      }
      
      // Simplify building geometry if needed
      return buildings.map((building) {
        // Skip simplification for already simple buildings
        final List<LatLng> points = building['points'] as List<LatLng>;
        if (points.length <= 5) return building;
        
        // Simplify geometry for complex buildings
        List<LatLng> simplifiedPoints = _simplifyPolygon(points, MapStyles.simplifyBuildingsTolerance);
        
        return {
          ...building,
          'points': simplifiedPoints,
        };
      }).toList();
    }
    
    return buildings;
  }
  
  // Implementation of Ramer-Douglas-Peucker algorithm for polygon simplification
  List<LatLng> _simplifyPolygon(List<LatLng> points, double tolerance) {
    if (points.length <= 4) return points; // Don't simplify very simple polygons
    
    // Make sure the polygon is closed
    final isClosed = points.first.latitude == points.last.latitude && 
                     points.first.longitude == points.last.longitude;
    
    final List<LatLng> workingPoints = isClosed ? points.sublist(0, points.length - 1) : points;
    final List<LatLng> simplified = _rdpSimplify(workingPoints, tolerance);
    
    // Close the polygon if it was closed before
    if (isClosed && simplified.isNotEmpty) {
      simplified.add(simplified.first);
    }
    
    return simplified;
  }
  
  // Ramer-Douglas-Peucker algorithm implementation
  List<LatLng> _rdpSimplify(List<LatLng> points, double epsilon) {
    if (points.length <= 2) return points;
    
    // Find the point with the maximum distance from line between start and end
    double dmax = 0.0;
    int index = 0;
    
    for (int i = 1; i < points.length - 1; i++) {
      double d = _perpendicularDistance(points[i], points[0], points[points.length - 1]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }
    
    // If max distance is greater than epsilon, recursively simplify
    List<LatLng> result = [];
    if (dmax > epsilon) {
      List<LatLng> recResults1 = _rdpSimplify(points.sublist(0, index + 1), epsilon);
      List<LatLng> recResults2 = _rdpSimplify(points.sublist(index), epsilon);
      
      // Build the result list
      result = recResults1.sublist(0, recResults1.length - 1)..addAll(recResults2);
    } else {
      result = [points[0], points[points.length - 1]];
    }
    
    return result;
  }
  
  // Calculate perpendicular distance from point to line
  double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    double area = (
      (lineEnd.latitude - lineStart.latitude) * (point.longitude - lineStart.longitude) -
      (lineEnd.longitude - lineStart.longitude) * (point.latitude - lineStart.latitude)
    ).abs() / 2;
    
    double base = math.sqrt(
      math.pow(lineEnd.latitude - lineStart.latitude, 2) +
      math.pow(lineEnd.longitude - lineStart.longitude, 2)
    );
    
    return area / base * 2;
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
    // Skip rendering if tilt is too small
    if (tiltFactor < 0.05) return;
    
    // Calculate the scale factor for building height based on zoom
    // Optimize: reduce height at lower zoom levels
    final double zoomFactor = math.min(1.0, (zoomLevel - 13) / 6); // Scale from 0-1 between zoom 13-19
    final heightScale = 0.0001 * math.pow(2, zoomLevel) * MapStyles.buildingHeightScale * zoomFactor;
    
    // Sort buildings by latitude (south to north) for proper rendering order
    // This is a simple approximation - a more accurate approach would sort by distance from camera
    final sortedBuildings = List<Map<String, dynamic>>.from(buildings)
      ..sort((a, b) {
        // Get center point of each building
        LatLng centerA = _calculateCenter(a['points'] as List<LatLng>);
        LatLng centerB = _calculateCenter(b['points'] as List<LatLng>);
        return centerB.latitude.compareTo(centerA.latitude);
      });
      
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // Building category colors based on types/importance
    Map<String, Color> buildingCategoryColors = {
      'commercial': MapStyles.commercialAreaColor,
      'retail': Color.lerp(buildingBaseColor, MapStyles.retailColor, 0.15)!,
      'office': Color.lerp(buildingBaseColor, Color(0xFF455A64), 0.2)!,
      'residential': Color.lerp(buildingBaseColor, MapStyles.residentialAreaColor, 0.1)!,
      'apartments': Color.lerp(buildingBaseColor, Color(0xFF5D4037), 0.1)!,
      'industrial': Color.lerp(buildingBaseColor, Color(0xFF424242), 0.15)!,
      'warehouse': Color.lerp(buildingBaseColor, Color(0xFF424242), 0.1)!,
      'hotel': Color.lerp(buildingBaseColor, MapStyles.entertainmentColor, 0.1)!,
      'supermarket': Color.lerp(buildingBaseColor, MapStyles.foodAndDrinkColor, 0.15)!,
      'restaurant': Color.lerp(buildingBaseColor, MapStyles.foodAndDrinkColor, 0.1)!,
      'university': Color.lerp(buildingBaseColor, Color(0xFF0097A7), 0.15)!,
      'school': Color.lerp(buildingBaseColor, Color(0xFF00897B), 0.1)!,
      'hospital': Color.lerp(buildingBaseColor, Color(0xFFEF5350), 0.1)!,
      'transportation': Color.lerp(buildingBaseColor, MapStyles.transportColor, 0.1)!,
      'train_station': Color.lerp(buildingBaseColor, MapStyles.transportColor, 0.15)!,
      'civic': Color.lerp(buildingBaseColor, MapStyles.landmarkColor, 0.15)!,
      'government': Color.lerp(buildingBaseColor, MapStyles.landmarkColor, 0.2)!,
      'historic': Color.lerp(buildingBaseColor, MapStyles.landmarkColor, 0.2)!,
      'attraction': Color.lerp(buildingBaseColor, MapStyles.entertainmentColor, 0.2)!,
    };
    
    // Draw each building
    for (final building in sortedBuildings) {
      final List<LatLng> points = building['points'] as List<LatLng>;
      if (points.length < 3) continue; // Skip invalid buildings
      
      // Extract building tags
      final Map<String, dynamic> tags = building['tags'] as Map<String, dynamic>;
      
      // Convert building height to screen units with optimization
      double buildingHeight = (building['height'] as double);
      
      // For important buildings at lower zoom levels, exaggerate height slightly
      if (zoomLevel < 16 && tags.containsKey('building:levels') && (tags['building:levels'] as String).isNotEmpty) {
        final levelsStr = tags['building:levels'] as String;
        final levels = double.tryParse(levelsStr) ?? 1.0;
        if (levels > 5) {
          // Exaggerate tall buildings at lower zoom levels for better visibility
          buildingHeight *= 1.2;
        }
      }
      
      // Apply height scaling
      buildingHeight *= heightScale * tiltFactor;
      
      // Convert LatLng points to screen coordinates
      final List<Offset> screenPoints = points.map((latLng) {
        // Map from LatLng to screen coordinates
        final double x = (latLng.longitude - sw.longitude) / mapWidth * size.width;
        final double y = (1 - (latLng.latitude - sw.latitude) / mapHeight) * size.height;
        return Offset(x, y);
      }).toList();
      
      // Calculate the average building position for shadow offset
      final avgX = screenPoints.fold<double>(0, (prev, point) => prev + point.dx) / screenPoints.length;
      final avgY = screenPoints.fold<double>(0, (prev, point) => prev + point.dy) / screenPoints.length;
      
      // Draw shadows first to ensure they appear behind buildings
      _drawBuildingShadow(canvas, screenPoints, buildingHeight, size);
      
      // Create the base building polygon - Use dart:ui Path
      final Path basePath = Path()..addPolygon(screenPoints, true);
      
      // Determine building color based on its type
      Color baseColor = buildingBaseColor;
      Color topColor = buildingTopColor;
      
      // Check if building has a specific type to assign a special color
      String? buildingType;
      
      // Check various OSM tags to determine building type
      if (tags.containsKey('building')) {
        String bType = tags['building'] as String;
        if (buildingCategoryColors.containsKey(bType)) {
          buildingType = bType;
        }
      }
      
      // Check amenity tag if building type is still unknown
      if (buildingType == null && tags.containsKey('amenity')) {
        String amenity = tags['amenity'] as String;
        if (amenity == 'restaurant' || amenity == 'cafe' || amenity == 'food_court') {
          buildingType = 'restaurant';
        } else if (amenity == 'university' || amenity == 'college') {
          buildingType = 'university';
        } else if (amenity == 'school') {
          buildingType = 'school';
        } else if (amenity == 'hospital' || amenity == 'clinic') {
          buildingType = 'hospital';
        } else if (amenity == 'theatre' || amenity == 'cinema' || amenity == 'arts_centre') {
          buildingType = 'attraction';
        }
      }
      
      // Check shop tag
      if (buildingType == null && tags.containsKey('shop')) {
        buildingType = 'retail';
      }
      
      // If we know the building type, assign the appropriate color
      if (buildingType != null && buildingCategoryColors.containsKey(buildingType)) {
        baseColor = buildingCategoryColors[buildingType]!;
        topColor = Color.lerp(buildingCategoryColors[buildingType]!, Colors.white, 0.15)!;
      }
      
      // Apply subtle color variation for visual interest
      final basePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _variateColor(baseColor);
      
      canvas.drawPath(basePath, basePaint);
      
      // Draw the extruded top face (roof) - Use dart:ui Path
      final Path roofPath = Path();
      final List<Offset> roofPoints = screenPoints.map((point) {
        return Offset(point.dx, point.dy - buildingHeight);
      }).toList();
      
      roofPath.addPolygon(roofPoints, true);
      
      final roofPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _variateColor(topColor);
      
      canvas.drawPath(roofPath, roofPaint);
      
      // Draw sides to connect base and roof
      for (int i = 0; i < screenPoints.length; i++) {
        final int nextIndex = (i + 1) % screenPoints.length;
        
        final Offset p1 = screenPoints[i];
        final Offset p2 = screenPoints[nextIndex];
        final Offset p3 = roofPoints[nextIndex];
        final Offset p4 = roofPoints[i];
        
        if (p1.dx == p2.dx && p1.dy == p2.dy) continue; // Skip zero-length segments
        
        // Side face path
        final Path sidePath = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();
        
        // Calculate side color - darker for sides that should be shaded
        final sideColor = _calculateSideColor(p1, p2, baseColor);
        final sidePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = sideColor;
        
        canvas.drawPath(sidePath, sidePaint);
      }
      
      // Add windows to large buildings for added detail when the building is big enough
      if (buildingHeight > 20 && zoomLevel >= 16) {
        _drawWindows(canvas, screenPoints, roofPoints, buildingHeight);
      }
    }
  }
  
  // Draw a shadow beneath the building for 2.5D effect
  void _drawBuildingShadow(Canvas canvas, List<Offset> screenPoints, double buildingHeight, Size size) {
    // Skip very small buildings or when tilt factor is minor
    if (buildingHeight < 5 || tiltFactor < 0.2) return;
    
    // Create a path for the shadow
    final Path shadowPath = Path();
    
    // Calculate shadow offset based on height and light direction
    final double shadowOffsetX = buildingHeight * 0.3;
    final double shadowOffsetY = buildingHeight * 0.15;
    
    // Create shadow points with offset
    final List<Offset> shadowPoints = screenPoints.map((point) {
      return Offset(point.dx + shadowOffsetX, point.dy + shadowOffsetY);
    }).toList();
    
    shadowPath.addPolygon(shadowPoints, true);
    
    // Draw shadow with gradient for more realistic feel
    final Paint shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(MapStyles.shadowOpacity * tiltFactor);  // Opacity based on tilt
    
    canvas.drawPath(shadowPath, shadowPaint);
  }
  
  // Calculate side color based on "light direction" to simulate lighting
  Color _calculateSideColor(Offset p1, Offset p2, Color baseColor) {
    // Simplified directional lighting - sides facing certain directions are darker
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    
    // Normalize the direction vector
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-6) return baseColor; // Avoid division by zero
    
    final nx = dx / length;
    final ny = dy / length;
    
    // Light direction vector (45 degrees from top-right)
    final double lightX = 0.7071;
    final double lightY = -0.7071;
    
    // Dot product with normal (perpendicular to wall direction)
    final double dotProduct = ny * lightX - nx * lightY;
    
    // Adjusted lighting factor based on dot product
    double factor = 0.5 + dotProduct * 0.5;
    factor = factor.clamp(0.65, 1.1);
    
    // Darken or lighten the base color 
    if (factor < 1.0) {
      return Color.lerp(baseColor, Colors.black, 1.0 - factor)!;
    } else {
      return Color.lerp(baseColor, Colors.white, factor - 1.0)!;
    }
  }
  
  // Draw windows on building sides for added realism
  void _drawWindows(Canvas canvas, List<Offset> basePoints, List<Offset> roofPoints, double buildingHeight) {
    // Window settings
    final double windowWidth = 3.0;
    final double windowHeight = 4.0;
    final double windowSpacingH = 5.0;
    final double windowSpacingV = 7.0;
    
    // Window paint
    final Paint windowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.15); // Subtle window glow
    
    // For each building side
    for (int i = 0; i < basePoints.length; i++) {
      final int nextIndex = (i + 1) % basePoints.length;
      
      final Offset p1 = basePoints[i];
      final Offset p2 = basePoints[nextIndex];
      final Offset p3 = roofPoints[nextIndex];
      final Offset p4 = roofPoints[i];
      
      // Skip very short walls
      final double wallLength = (p2 - p1).distance;
      if (wallLength < 15) continue;
      
      // Skip nearly horizontal or vertical walls (they'll look strange with windows)
      final double dx = (p2.dx - p1.dx).abs();
      final double dy = (p2.dy - p1.dy).abs();
      if (dx < 1 || dy < 1) continue;
      
      // Calculate the wall direction vector
      double dirX = (p2.dx - p1.dx) / wallLength;
      double dirY = (p2.dy - p1.dy) / wallLength;
      
      // Calculate how many windows fit horizontally and vertically
      final int numWindowsH = (wallLength / (windowWidth + windowSpacingH)).floor();
      final int numWindowsV = (buildingHeight / (windowHeight + windowSpacingV)).floor();
      
      // If the wall is too small, skip window rendering
      if (numWindowsH < 1 || numWindowsV < 1) continue;
      
      // Actual spacing to distribute windows evenly
      final double actualSpacingH = (wallLength - (numWindowsH * windowWidth)) / (numWindowsH + 1);
      final double actualSpacingV = (buildingHeight - (numWindowsV * windowHeight)) / (numWindowsV + 1);
      
      // Draw grid of windows
      for (int col = 0; col < numWindowsH; col++) {
        for (int row = 0; row < numWindowsV; row++) {
          // Light up random windows (some on, some off)
          if (_random.nextDouble() > 0.7) { // 30% of windows are lit
            // Position along the wall
            final double posH = actualSpacingH + col * (windowWidth + actualSpacingH);
            final double posV = actualSpacingV + row * (windowHeight + actualSpacingV);
            
            // Calculate window position
            final double windowX = p1.dx + posH * dirX;
            final double windowY = p1.dy + posH * dirY;
            
            // Draw window rectangle
            final Rect windowRect = Rect.fromLTWH(
              windowX - (windowWidth / 2), 
              windowY - (windowHeight / 2) - posV, 
              windowWidth, 
              windowHeight
            );
            
            canvas.drawRect(windowRect, windowPaint);
          }
        }
      }
    }
  }
  
  // Calculate center point of a building for sorting/positioning
  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    
    double sumLat = 0;
    double sumLng = 0;
    
    for (final point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    
    return LatLng(sumLat / points.length, sumLng / points.length);
  }
  
  // Add small variations to colors for visual interest
  Color _variateColor(Color color) {
    // Add slight variation to create more natural appearance
    final int variation = (_random.nextInt(15) - 7); // -7 to +7 variation
    
    // Apply variation to each color component
    int r = (color.red + variation).clamp(0, 255);
    int g = (color.green + variation).clamp(0, 255);
    int b = (color.blue + variation).clamp(0, 255);
    
    return Color.fromARGB(color.alpha, r, g, b);
  }
  
  @override
  bool shouldRepaint(OSMBuildingsPainter oldDelegate) {
    return oldDelegate.buildings != buildings ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.mapBounds != mapBounds;
  }
} 