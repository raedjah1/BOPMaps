import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import 'osm_data_processor.dart';
import '../../../services/map_cache_manager.dart';
import '../map_caching/map_cache_extension.dart';
import '../map_styles.dart';

/// A custom layer to render OpenStreetMap Points of Interest (POIs)
class OSMPointsOfInterestLayer extends StatefulWidget {
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final double tiltFactor;
  final bool isMapMoving;
  
  const OSMPointsOfInterestLayer({
    Key? key,
    required this.zoomLevel,
    required this.visibleBounds,
    this.tiltFactor = 1.0,
    this.isMapMoving = false,
  }) : super(key: key);

  @override
  State<OSMPointsOfInterestLayer> createState() => _OSMPointsOfInterestLayerState();
}

class _OSMPointsOfInterestLayerState extends State<OSMPointsOfInterestLayer> with SingleTickerProviderStateMixin {
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  List<Map<String, dynamic>> _pois = [];
  bool _isLoading = true;
  bool _needsRefresh = true;
  String _lastBoundsKey = "";
  
  // Animation controller for pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // POI categories and icons mapping
  final Map<String, IconData> _poiIcons = {
    'restaurant': Icons.restaurant,
    'cafe': Icons.coffee,
    'bar': Icons.local_bar,
    'fast_food': Icons.fastfood,
    'hotel': Icons.hotel,
    'theatre': Icons.theater_comedy,
    'cinema': Icons.movie,
    'museum': Icons.museum,
    'shop': Icons.shopping_bag,
    'supermarket': Icons.shopping_cart,
    'attraction': Icons.attractions,
    'entertainment': Icons.celebration,
    'library': Icons.local_library,
    'university': Icons.school,
    'hospital': Icons.local_hospital,
    'parking': Icons.local_parking,
    'fuel': Icons.local_gas_station,
    'bank': Icons.account_balance,
    'arts_centre': Icons.brush,
    'nightclub': Icons.nightlife,
    'marketplace': Icons.storefront,
    'park': Icons.park,
    'gallery': Icons.photo,
    'landmark': Icons.location_city,
    'viewpoint': Icons.photo_camera,
  };
  
  // POI categories and colors mapping
  final Map<String, Color> _poiColors = {
    'restaurant': MapStyles.foodAndDrinkColor,
    'cafe': MapStyles.foodAndDrinkColor.withOpacity(0.9),
    'bar': MapStyles.foodAndDrinkColor.withOpacity(0.8),
    'fast_food': MapStyles.foodAndDrinkColor.withOpacity(0.7),
    'hotel': MapStyles.entertainmentColor.withOpacity(0.9),
    'theatre': MapStyles.entertainmentColor,
    'cinema': MapStyles.entertainmentColor,
    'museum': Color.lerp(MapStyles.entertainmentColor, MapStyles.landmarkColor, 0.5)!,
    'shop': MapStyles.retailColor,
    'supermarket': MapStyles.retailColor.withOpacity(0.9),
    'attraction': MapStyles.entertainmentColor,
    'entertainment': MapStyles.entertainmentColor,
    'library': Color.lerp(MapStyles.entertainmentColor, MapStyles.landmarkColor, 0.5)!,
    'university': Color(0xFF42A5F5),
    'hospital': Color(0xFFEF5350),
    'parking': MapStyles.transportColor.withOpacity(0.7),
    'fuel': MapStyles.transportColor.withOpacity(0.8),
    'bank': Color(0xFF66BB6A),
    'arts_centre': MapStyles.entertainmentColor.withOpacity(0.9),
    'nightclub': Color.lerp(MapStyles.entertainmentColor, Colors.deepPurple, 0.3)!,
    'marketplace': MapStyles.retailColor.withOpacity(0.8),
    'park': Color(0xFF388E3C),
    'gallery': MapStyles.entertainmentColor.withOpacity(0.85),
    'landmark': MapStyles.landmarkColor,
    'viewpoint': MapStyles.landmarkColor.withOpacity(0.9),
  };
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for pulsing effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    _fetchPOIs();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OSMPointsOfInterestLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Calculate a key to identify the current visible bounds
    final newBoundsKey = _getBoundsKey();
    
    // Only fetch new POIs when zoom level changes significantly or bounds change
    if (oldWidget.zoomLevel != widget.zoomLevel || _lastBoundsKey != newBoundsKey) {
      _needsRefresh = true;
      
      // If map is actively moving, only use delayed fetch to reduce API load
      if (widget.isMapMoving) {
        _delayedFetch();
      }
      // Immediate refresh for significant zoom changes, delayed for others
      else if ((oldWidget.zoomLevel - widget.zoomLevel).abs() > 0.5) {
        _fetchPOIs();
      } else {
        _delayedFetch();
      }
    }
  }
  
  // Get a key to identify current map bounds
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
        _fetchPOIs();
      }
    });
  }
  
  void _fetchPOIs() async {
    // Skip fetching POIs at lower zoom levels
    if (widget.zoomLevel < 14.5) {
      if (mounted) {
        setState(() {
          _pois = [];
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
    
    // Use the map bounds to fetch POIs
    final southwest = widget.visibleBounds.southWest;
    final northeast = widget.visibleBounds.northEast;
    
    try {
      final pois = await _dataProcessor.fetchPOIData(southwest, northeast);
      
      if (mounted) {
        // Apply filters and optimizations
        final optimizedPOIs = _optimizePOIs(pois);
        
        setState(() {
          _pois = optimizedPOIs;
          _isLoading = false;
          _needsRefresh = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching POIs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _needsRefresh = false;
        });
      }
    }
  }
  
  // Filter and optimize POIs based on zoom level
  List<Map<String, dynamic>> _optimizePOIs(List<Map<String, dynamic>> pois) {
    if (pois.isEmpty) return [];
    
    // At different zoom levels, show different densities and types of POIs
    List<String> visibleCategories = [];
    int maxPOIs = 200; // Default cap
    
    if (widget.zoomLevel < 15.0) {
      // At low zoom, only show major landmarks, stations, etc.
      visibleCategories = ['theatre', 'cinema', 'museum', 'supermarket', 'attraction', 
                          'hospital', 'university', 'landmark', 'arts_centre'];
      maxPOIs = 30;
    } else if (widget.zoomLevel < 16.0) {
      // Mid zoom, add restaurants, hotels, etc.
      visibleCategories = ['restaurant', 'hotel', 'theatre', 'cinema', 'museum', 
                          'supermarket', 'attraction', 'entertainment', 'hospital', 
                          'university', 'landmark', 'arts_centre', 'nightclub'];
      maxPOIs = 60;
    } else if (widget.zoomLevel < 17.0) {
      // Higher zoom, add more types
      visibleCategories = ['restaurant', 'cafe', 'bar', 'hotel', 'theatre', 'cinema', 
                          'museum', 'shop', 'supermarket', 'attraction', 'entertainment', 
                          'library', 'university', 'hospital', 'arts_centre', 'nightclub', 
                          'landmark', 'viewpoint', 'gallery', 'marketplace'];
      maxPOIs = 100;
    } else {
      // Highest zoom, show everything
      visibleCategories = _poiColors.keys.toList();
      maxPOIs = 200;
    }
    
    // Filter POIs by category
    pois = pois.where((poi) {
      final category = poi['category'] as String? ?? 'unknown';
      return visibleCategories.contains(category);
    }).toList();
    
    // Limit the number of POIs
    if (pois.length > maxPOIs) {
      // Sort by importance/rating before limiting
      pois.sort((a, b) {
        final aRating = a['importance'] as double? ?? 0.5;
        final bRating = b['importance'] as double? ?? 0.5;
        return bRating.compareTo(aRating);
      });
      
      pois = pois.sublist(0, maxPOIs);
    }
    
    return pois;
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while loading or if POIs list is empty
    if (_isLoading || _pois.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: POIPainter(
            pois: _pois,
            zoomLevel: widget.zoomLevel,
            mapBounds: widget.visibleBounds,
            tiltFactor: widget.tiltFactor,
            poiIcons: _poiIcons,
            poiColors: _poiColors,
            pulseValue: _pulseAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class POIPainter extends CustomPainter {
  final List<Map<String, dynamic>> pois;
  final double zoomLevel;
  final LatLngBounds mapBounds;
  final double tiltFactor;
  final Map<String, IconData> poiIcons;
  final Map<String, Color> poiColors;
  final double pulseValue;
  final math.Random _random = math.Random(42); // Consistent seed for reproducibility
  
  POIPainter({
    required this.pois,
    required this.zoomLevel,
    required this.mapBounds,
    required this.tiltFactor,
    required this.poiIcons,
    required this.poiColors,
    required this.pulseValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Bounds conversion helpers
    final sw = mapBounds.southWest;
    final ne = mapBounds.northEast;
    final mapWidth = ne.longitude - sw.longitude;
    final mapHeight = ne.latitude - sw.latitude;
    
    // Calculate size based on zoom level
    double baseSize = 14.0 * (1 + (zoomLevel - 15) * 0.2).clamp(0.7, 1.5);
    
    // Sort POIs by category (for layering) and importance
    final sortedPOIs = List<Map<String, dynamic>>.from(pois)
      ..sort((a, b) {
        final aCategory = a['category'] as String? ?? 'unknown';
        final bCategory = b['category'] as String? ?? 'unknown';
        
        // Sort first by category priority
        final aPriority = _getCategoryPriority(aCategory);
        final bPriority = _getCategoryPriority(bCategory);
        
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        
        // Then by importance
        final aImportance = a['importance'] as double? ?? 0.5;
        final bImportance = b['importance'] as double? ?? 0.5;
        return bImportance.compareTo(aImportance);
      });
    
    // Draw each POI
    for (final poi in sortedPOIs) {
      final LatLng location = poi['location'] as LatLng;
      final category = poi['category'] as String? ?? 'unknown';
      final name = poi['name'] as String? ?? '';
      final importance = poi['importance'] as double? ?? 0.5;
      
      // Map from LatLng to screen coordinates
      final double x = (location.longitude - sw.longitude) / mapWidth * size.width;
      final double y = (1 - (location.latitude - sw.latitude) / mapHeight) * size.height;
      
      // Account for tilt in y position (POIs closer to the bottom of the screen appear higher)
      final double tiltedY = y - (y / size.height) * 50 * tiltFactor;
      
      // Get POI color and icon
      Color poiColor = poiColors[category] ?? Colors.grey;
      IconData poiIcon = poiIcons[category] ?? Icons.place;
      
      // Apply pulse effect to important POIs
      double poiSize = baseSize;
      double opacity = 0.95;
      
      // Important POIs are bigger and can pulse
      if (importance > 0.7) {
        poiSize *= 1.2;
        // Apply pulse only to important POIs
        poiSize *= pulseValue;
        opacity = 1.0;
      }
      
      // Add slight variation to avoid monotony
      poiSize *= 0.9 + _random.nextDouble() * 0.2;
      
      // Draw shadow first
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3 * tiltFactor)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x + poiSize * 0.2, tiltedY + poiSize * 0.3),
        poiSize * 0.8,
        shadowPaint
      );
      
      // Draw POI circle background
      final circlePaint = Paint()
        ..color = poiColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x, tiltedY), 
        poiSize,
        circlePaint
      );
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(
        Offset(x, tiltedY), 
        poiSize,
        borderPaint
      );
      
      // Draw icon inside
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(poiIcon.codePoint),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: poiSize * 1.2,
            fontFamily: poiIcon.fontFamily,
            package: poiIcon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x - textPainter.width / 2,
          tiltedY - textPainter.height / 2,
        ),
      );
      
      // Draw name for important POIs at high zoom levels
      if (zoomLevel >= 17.0 && importance > 0.6 && name.isNotEmpty) {
        _drawPOIName(canvas, name, x, tiltedY + poiSize + 8, poiSize);
      }
    }
  }
  
  // Helper to draw POI name
  void _drawPOIName(Canvas canvas, String name, double x, double y, double poiSize) {
    // Limit name length to avoid very long texts
    String displayName = name;
    if (name.length > 20) {
      displayName = name.substring(0, 17) + '...';
    }
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: poiSize * 0.9,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 3,
              color: Colors.black.withOpacity(0.7),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // Draw background pill
    final bgRect = Rect.fromCenter(
      center: Offset(x, y + textPainter.height / 2),
      width: textPainter.width + 10,
      height: textPainter.height + 4,
    );
    
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(10));
    canvas.drawRRect(rrect, bgPaint);
    
    // Draw text
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y),
    );
  }
  
  // Assign priority to categories for layering (lower number = drawn first/on bottom)
  int _getCategoryPriority(String category) {
    // Define priority tiers - higher numbers will be drawn on top
    final Map<String, int> priorities = {
      'park': 1,
      'parking': 2,
      'fuel': 3,
      'shop': 4,
      'supermarket': 5,
      'restaurant': 6,
      'cafe': 7,
      'bar': 8,
      'fast_food': 8,
      'hotel': 9,
      'hospital': 10,
      'university': 9,
      'library': 9,
      'entertainment': 11,
      'arts_centre': 12,
      'theatre': 13,
      'cinema': 13,
      'museum': 14,
      'gallery': 14,
      'nightclub': 15,
      'attraction': 16,
      'landmark': 17,
      'viewpoint': 16,
    };
    
    return priorities[category] ?? 5; // Default priority for unknown categories
  }
  
  @override
  bool shouldRepaint(POIPainter oldDelegate) {
    return oldDelegate.pois != pois ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.mapBounds != mapBounds;
  }
} 