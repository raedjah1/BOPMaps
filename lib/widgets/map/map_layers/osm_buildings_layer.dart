import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hide Path from latlong2
import 'dart:math' as math;
import 'dart:ui'; // Explicitly import dart:ui for Path

import 'osm_data_processor.dart';

// Extension to add normalize method to Offset
extension OffsetExtensions on Offset {
  Offset normalize() {
    final double magnitude = distance;
    if (magnitude == 0) return Offset.zero;
    return Offset(dx / magnitude, dy / magnitude);
  }
}

/// A custom layer to render OpenStreetMap buildings in 2.5D
class OSMBuildingsLayer extends StatefulWidget {
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final bool isMapMoving;
  final String theme; // Added theme parameter for customization
  
  const OSMBuildingsLayer({
    Key? key,
    this.tiltFactor = 1.0,
    required this.zoomLevel,
    required this.visibleBounds,
    this.isMapMoving = false,
    this.theme = 'vibrant', // Default to vibrant theme
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
  String _currentTheme = 'vibrant';
  
  // Track last fetch params to avoid unnecessary fetches
  LatLngBounds? _lastFetchedBounds;
  double _lastFetchedZoom = 0;
  bool _didInitialFetch = false;
  
  // Building color palettes for different themes
  final Map<String, Map<String, Map<String, Color>>> _buildingColorPalette = {
    'vibrant': {
      'commercial': {
        'wall': const Color(0xFF7986CB), 
        'roof': const Color(0xFF5C6BC0)
      },
      'residential': {
        'wall': const Color(0xFFFFB74D), 
        'roof': const Color(0xFFFF9800)
      },
      'office': {
        'wall': const Color(0xFF4FC3F7), 
        'roof': const Color(0xFF29B6F6)
      },
      'industrial': {
        'wall': const Color(0xFF90A4AE), 
        'roof': const Color(0xFF78909C)
      },
      'education': {
        'wall': const Color(0xFF81C784), 
        'roof': const Color(0xFF66BB6A)
      },
      'healthcare': {
        'wall': const Color(0xFFE57373), 
        'roof': const Color(0xFFEF5350)
      },
      'public': {
        'wall': const Color(0xFFBA68C8), 
        'roof': const Color(0xFFAB47BC)
      },
      'historic': {
        'wall': const Color(0xFFD4B178), 
        'roof': const Color(0xFFC19A57)
      },
      'default': {
        'wall': const Color(0xFFBDBDBD), 
        'roof': const Color(0xFF9E9E9E)
      },
    },
    'dark': {
      'commercial': {
        'wall': const Color(0xFF5C6BC0).withAlpha(220), 
        'roof': const Color(0xFF3F51B5).withAlpha(220)
      },
      'residential': {
        'wall': const Color(0xFFFF9800).withAlpha(220), 
        'roof': const Color(0xFFF57C00).withAlpha(220)
      },
      'office': {
        'wall': const Color(0xFF0288D1).withAlpha(220), 
        'roof': const Color(0xFF0277BD).withAlpha(220)
      },
      'industrial': {
        'wall': const Color(0xFF546E7A).withAlpha(220), 
        'roof': const Color(0xFF455A64).withAlpha(220)
      },
      'education': {
        'wall': const Color(0xFF388E3C).withAlpha(220), 
        'roof': const Color(0xFF2E7D32).withAlpha(220)
      },
      'healthcare': {
        'wall': const Color(0xFFD32F2F).withAlpha(220), 
        'roof': const Color(0xFFC62828).withAlpha(220)
      },
      'public': {
        'wall': const Color(0xFF8E24AA).withAlpha(220), 
        'roof': const Color(0xFF7B1FA2).withAlpha(220)
      },
      'historic': {
        'wall': const Color(0xFFAA8E57).withAlpha(220), 
        'roof': const Color(0xFF8D6E3A).withAlpha(220)
      },
      'default': {
        'wall': const Color(0xFF616161).withAlpha(220), 
        'roof': const Color(0xFF424242).withAlpha(220)
      },
    },
    // Monochrome Uber-like theme
    'monochrome': {
      'commercial': {
        'wall': const Color(0xFF374151), 
        'roof': const Color(0xFF1F2937)
      },
      'residential': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
      'office': {
        'wall': const Color(0xFF1F2937), 
        'roof': const Color(0xFF111827)
      },
      'industrial': {
        'wall': const Color(0xFF6B7280), 
        'roof': const Color(0xFF4B5563)
      },
      'education': {
        'wall': const Color(0xFF374151), 
        'roof': const Color(0xFF1F2937)
      },
      'healthcare': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
      'public': {
        'wall': const Color(0xFF6B7280), 
        'roof': const Color(0xFF4B5563)
      },
      'historic': {
        'wall': const Color(0xFF1F2937), 
        'roof': const Color(0xFF111827)
      },
      'default': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
    },
  };
  
  // Rooftop colors for different themes
  final Map<String, Map<String, Color>> _rooftopColors = {
    'vibrant': {
      'default': const Color(0xFFCFCFCF),   // Lighter gray for roofs
      'commercial': const Color(0xFFCE93D8), // Darker purple for commercial
      'residential': const Color(0xFFFFAB91), // Darker peach for residential
      'office': const Color(0xFF80CBC4),    // Darker teal for office
      'industrial': const Color(0xFFFFCA28), // Darker amber for industrial
      'retail': const Color(0xFFF48FB1),    // Darker pink for retail
      'public': const Color(0xFF64B5F6),    // Darker blue for public
      'education': const Color(0xFFAED581), // Darker green for education
      'healthcare': const Color(0xFFEC407A), // Bright pink for healthcare
      'historic': const Color(0xFFDCE775),  // Darker lime for historic
    },
    'dark': {
      'default': const Color(0xFF616161),   // Dark gray for roofs
      'commercial': const Color(0xFF6A1B9A).withOpacity(0.9),  // Very dark purple
      'residential': const Color(0xFFE64A19).withOpacity(0.9),  // Dark orange
      'office': const Color(0xFF00897B).withOpacity(0.9),     // Dark teal
      'industrial': const Color(0xFFFF8F00).withOpacity(0.9),  // Dark amber
      'retail': const Color(0xFFC2185B).withOpacity(0.9),     // Dark pink
      'public': const Color(0xFF1565C0).withOpacity(0.9),     // Dark blue
      'education': const Color(0xFF558B2F).withOpacity(0.9),  // Dark green
      'healthcare': const Color(0xFFC2185B).withOpacity(0.9),  // Dark pink
      'historic': const Color(0xFFAFB42B).withOpacity(0.9),   // Dark lime
    },
  };
  
  @override
  void initState() {
    super.initState();
    _currentTheme = widget.theme;
    _fetchBuildings();
  }
  
  @override
  void didUpdateWidget(OSMBuildingsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update theme if it changed
    if (widget.theme != _currentTheme) {
      setState(() {
        _currentTheme = widget.theme;
      });
    }
    
    // Skip updates if map is moving for better performance
    if (widget.isMapMoving && _buildings.isNotEmpty) {
      return;
    }
    
    // Check if we need to update data - significant bounds/zoom change
    final boundsChanged = _lastFetchedBounds == null || 
        !_areBoundsSimilar(_lastFetchedBounds!, widget.visibleBounds);
    final zoomChanged = (_lastFetchedZoom - widget.zoomLevel).abs() >= 1.0;
    
    if (boundsChanged || zoomChanged) {
      _fetchBuildings();
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
  
  // Check if bounds are similar enough to avoid unnecessary fetches
  bool _areBoundsSimilar(LatLngBounds bounds1, LatLngBounds bounds2) {
    // Calculate center points
    final LatLng center1 = LatLng(
      (bounds1.north + bounds1.south) / 2,
      (bounds1.east + bounds1.west) / 2,
    );
    final LatLng center2 = LatLng(
      (bounds2.north + bounds2.south) / 2,
      (bounds2.east + bounds2.west) / 2,
    );
    
    // Calculate distance between centers (in degrees)
    final double latDiff = (center1.latitude - center2.latitude).abs();
    final double lngDiff = (center1.longitude - center2.longitude).abs();
    
    // Calculate size of bounds (in degrees)
    final double bounds1Height = bounds1.north - bounds1.south;
    final double bounds1Width = bounds1.east - bounds1.west;
    
    // If centers differ by more than 30% of the bounds size, consider them different
    return latDiff < (bounds1Height * 0.3) && lngDiff < (bounds1Width * 0.3);
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
      setState(() {
        _buildings = buildings;
        _isLoading = false;
        _needsRefresh = false;
        _lastFetchedBounds = widget.visibleBounds;
        _lastFetchedZoom = widget.zoomLevel;
        _didInitialFetch = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine effective theme (adapt to system theme or use explicit theme)
    final effectiveTheme = widget.theme == 'auto' 
        ? MediaQuery.of(context).platformBrightness == Brightness.dark ? 'dark' : 'vibrant'
        : widget.theme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoading && !_didInitialFetch) {
          // Show loading indicator on first load
          return Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }
        
        if (_buildings.isEmpty && _didInitialFetch) {
          // No buildings found but we did search
      return const SizedBox.shrink();
    }
    
    return CustomPaint(
          size: Size(
            constraints.maxWidth,
            constraints.maxHeight,
          ),
      painter: OSMBuildingsPainter(
        buildings: _buildings,
        tiltFactor: widget.tiltFactor,
        zoomLevel: widget.zoomLevel,
            visibleBounds: widget.visibleBounds,
            theme: effectiveTheme, // Pass theme to painter
          ),
          // Add overlay for interactive building selection if needed
          child: widget.zoomLevel >= 17.0 ? GestureDetector(
            onTapDown: _handleTapDown,
            child: Container(color: Colors.transparent),
          ) : null,
        );
      },
    );
  }
  
  // Handle taps on buildings for future interactive features
  void _handleTapDown(TapDownDetails details) {
    // Get tap position
    final tapPosition = details.localPosition;
    
    // Find building under tap
    // This would be implemented to detect which building was tapped
    // for implementing selection, info display, etc.
    
    // For future implementation - can use hit testing with paths
  }
}

/// Custom painter to render buildings in 2.5D
class OSMBuildingsPainter extends CustomPainter {
  final List<Map<String, dynamic>> buildings;
  final double tiltFactor;
  final double zoomLevel;
  final LatLngBounds visibleBounds;
  final String theme;
  final math.Random _random = math.Random(42); // Add random generator with fixed seed
  
  OSMBuildingsPainter({
    required this.buildings,
    required this.tiltFactor,
    required this.zoomLevel,
    required this.visibleBounds,
    required this.theme,
  });
  
  // Building color palettes for different themes
  final Map<String, Map<String, Map<String, Color>>> _buildingColorPalette = {
    'vibrant': {
      'commercial': {
        'wall': const Color(0xFF7986CB), 
        'roof': const Color(0xFF5C6BC0)
      },
      'residential': {
        'wall': const Color(0xFFFFB74D), 
        'roof': const Color(0xFFFF9800)
      },
      'office': {
        'wall': const Color(0xFF4FC3F7), 
        'roof': const Color(0xFF29B6F6)
      },
      'industrial': {
        'wall': const Color(0xFF90A4AE), 
        'roof': const Color(0xFF78909C)
      },
      'education': {
        'wall': const Color(0xFF81C784), 
        'roof': const Color(0xFF66BB6A)
      },
      'healthcare': {
        'wall': const Color(0xFFE57373), 
        'roof': const Color(0xFFEF5350)
      },
      'public': {
        'wall': const Color(0xFFBA68C8), 
        'roof': const Color(0xFFAB47BC)
      },
      'historic': {
        'wall': const Color(0xFFD4B178), 
        'roof': const Color(0xFFC19A57)
      },
      'default': {
        'wall': const Color(0xFFBDBDBD), 
        'roof': const Color(0xFF9E9E9E)
      },
    },
    'dark': {
      'commercial': {
        'wall': const Color(0xFF5C6BC0).withAlpha(220), 
        'roof': const Color(0xFF3F51B5).withAlpha(220)
      },
      'residential': {
        'wall': const Color(0xFFFF9800).withAlpha(220), 
        'roof': const Color(0xFFF57C00).withAlpha(220)
      },
      'office': {
        'wall': const Color(0xFF0288D1).withAlpha(220), 
        'roof': const Color(0xFF0277BD).withAlpha(220)
      },
      'industrial': {
        'wall': const Color(0xFF546E7A).withAlpha(220), 
        'roof': const Color(0xFF455A64).withAlpha(220)
      },
      'education': {
        'wall': const Color(0xFF388E3C).withAlpha(220), 
        'roof': const Color(0xFF2E7D32).withAlpha(220)
      },
      'healthcare': {
        'wall': const Color(0xFFD32F2F).withAlpha(220), 
        'roof': const Color(0xFFC62828).withAlpha(220)
      },
      'public': {
        'wall': const Color(0xFF8E24AA).withAlpha(220), 
        'roof': const Color(0xFF7B1FA2).withAlpha(220)
      },
      'historic': {
        'wall': const Color(0xFFAA8E57).withAlpha(220), 
        'roof': const Color(0xFF8D6E3A).withAlpha(220)
      },
      'default': {
        'wall': const Color(0xFF616161).withAlpha(220), 
        'roof': const Color(0xFF424242).withAlpha(220)
      },
    },
    // Monochrome Uber-like theme
    'monochrome': {
      'commercial': {
        'wall': const Color(0xFF374151), 
        'roof': const Color(0xFF1F2937)
      },
      'residential': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
      'office': {
        'wall': const Color(0xFF1F2937), 
        'roof': const Color(0xFF111827)
      },
      'industrial': {
        'wall': const Color(0xFF6B7280), 
        'roof': const Color(0xFF4B5563)
      },
      'education': {
        'wall': const Color(0xFF374151), 
        'roof': const Color(0xFF1F2937)
      },
      'healthcare': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
      'public': {
        'wall': const Color(0xFF6B7280), 
        'roof': const Color(0xFF4B5563)
      },
      'historic': {
        'wall': const Color(0xFF1F2937), 
        'roof': const Color(0xFF111827)
      },
      'default': {
        'wall': const Color(0xFF4B5563), 
        'roof': const Color(0xFF374151)
      },
    },
  };
  
  // Rooftop colors for different themes
  final Map<String, Map<String, Color>> _rooftopColors = {
    'vibrant': {
      'default': const Color(0xFFCFCFCF),   // Lighter gray for roofs
      'commercial': const Color(0xFFCE93D8), // Darker purple for commercial
      'residential': const Color(0xFFFFAB91), // Darker peach for residential
      'office': const Color(0xFF80CBC4),    // Darker teal for office
      'industrial': const Color(0xFFFFCA28), // Darker amber for industrial
      'retail': const Color(0xFFF48FB1),    // Darker pink for retail
      'public': const Color(0xFF64B5F6),    // Darker blue for public
      'education': const Color(0xFFAED581), // Darker green for education
      'healthcare': const Color(0xFFEC407A), // Bright pink for healthcare
      'historic': const Color(0xFFDCE775),  // Darker lime for historic
    },
    'dark': {
      'default': const Color(0xFF616161),   // Dark gray for roofs
      'commercial': const Color(0xFF6A1B9A).withOpacity(0.9),  // Very dark purple
      'residential': const Color(0xFFE64A19).withOpacity(0.9),  // Dark orange
      'office': const Color(0xFF00897B).withOpacity(0.9),     // Dark teal
      'industrial': const Color(0xFFFF8F00).withOpacity(0.9),  // Dark amber
      'retail': const Color(0xFFC2185B).withOpacity(0.9),     // Dark pink
      'public': const Color(0xFF1565C0).withOpacity(0.9),     // Dark blue
      'education': const Color(0xFF558B2F).withOpacity(0.9),  // Dark green
      'healthcare': const Color(0xFFC2185B).withOpacity(0.9),  // Dark pink
      'historic': const Color(0xFFAFB42B).withOpacity(0.9),   // Dark lime
    },
  };
  
  @override
  void paint(Canvas canvas, Size size) {
    if (buildings.isEmpty) return;
    
    final Paint buildingPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.0;
    
    final Paint roofPaint = Paint()
      ..style = PaintingStyle.fill;
    
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black.withOpacity(0.3);
    
    // Scale and position calculations
    final double latSpan = visibleBounds.north - visibleBounds.south;
    final double lngSpan = visibleBounds.east - visibleBounds.west;
    
    for (var building in buildings) {
      if (building['points'].isEmpty) continue;
      
      final path = Path();
      
      // Convert all nodes of the building to screen coordinates
      final List<Offset> screenPoints = (building['points'] as List<LatLng>).map((point) {
        final double x = ((point.longitude - visibleBounds.west) / lngSpan) * size.width;
        final double y = (1 - ((point.latitude - visibleBounds.south) / latSpan)) * size.height;
        return Offset(x, y);
      }).toList();
      
      if (screenPoints.isEmpty) continue;
      
      // Start the path at the first point
      path.moveTo(screenPoints[0].dx, screenPoints[0].dy);
      
      // Add all other points
      for (int i = 1; i < screenPoints.length; i++) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
      
      // Close the path
      path.close();
      
      // Determine building type and height
      final Map<String, dynamic> tags = building['tags'] as Map<String, dynamic>;
      final String buildingType = tags['building'] ?? 'yes';
      
      // Default height if not specified
      double height = 10.0;
      
      // Parse height from tags if available
      if (tags.containsKey('height')) {
        try {
          height = double.parse(tags['height'] as String);
        } catch (e) {
          // If parse fails, use default height
        }
      } else if (tags.containsKey('building:levels')) {
        try {
          // Approximate 3 meters per level
          height = double.parse(tags['building:levels'] as String) * 3.0;
        } catch (e) {
          // If parse fails, use default height
        }
      }
      
      // Adjust height for special building types
      if (buildingType == 'cathedral' || buildingType == 'church') {
        height = height * 1.5;
      } else if (buildingType == 'skyscraper') {
        height = height * 2.0;
      }
      
      // Get colors based on building type
      final Color wallColor = _getBuildingColor(tags);
      final Color roofColor = _getRoofColor(tags);
      
      // For higher zoom levels, draw enhanced buildings with 3D effect
      if (zoomLevel >= 15.0) {
        _drawEnhancedBuilding(
          canvas,
          path,
          height,
          wallColor,
          roofColor,
          screenPoints,
          zoomLevel,
          tags,
        );
      } else {
        // For lower zoom levels, use simpler rendering
        buildingPaint.color = wallColor;
        roofPaint.color = roofColor;
        
        // Draw shadow if tilted
        if (tiltFactor > 0.05) {
          final shadowPath = Path.from(path);
          shadowPath.shift(Offset(1.0, 1.0));
          canvas.drawPath(
            shadowPath,
            Paint()
              ..color = Colors.black.withOpacity(0.2)
              ..style = PaintingStyle.fill,
          );
        }
        
        // Draw building base
        canvas.drawPath(path, buildingPaint);
        
        // Draw outline
        canvas.drawPath(path, outlinePaint);
      }
    }
  }
  
  // Gets the appropriate building color based on building type and theme
  Color _getBuildingColor(Map<String, dynamic> tags) {
    final String buildingType = _getBuildingType(tags);
    final double height = _getBuildingHeight(tags);
    
    // Get the color map for the current theme, or fall back to vibrant theme
    final Map<String, Map<String, Color>>? themeColors = _buildingColorPalette[theme];
    if (themeColors == null) {
      return _buildingColorPalette['vibrant']?['default']?['wall'] ?? const Color(0xFFBDBDBD);
    }
    
    // Adjust opacity based on height for taller buildings
    double opacity = 0.85;
    if (height > 20) {
      opacity = 0.9;
    } else if (height > 50) {
      opacity = 0.95;
    }
    
    // Return specific color for the building type or default
    return (themeColors[buildingType]?['wall'] ?? themeColors['default']?['wall'] ?? const Color(0xFFBDBDBD)).withOpacity(opacity);
  }
  
  // Helper method to get building type from tags
  String _getBuildingType(Map<String, dynamic> tags) {
    final String buildingType = tags['building'] ?? 'yes';
    
    // Map general building types to our color categories
    if (buildingType == 'commercial' || buildingType == 'retail' || buildingType == 'shop') {
      return 'commercial';
    } else if (buildingType == 'residential' || buildingType == 'house' || buildingType == 'apartments') {
      return 'residential';
    } else if (buildingType == 'office') {
      return 'office';
    } else if (buildingType == 'industrial' || buildingType == 'warehouse') {
      return 'industrial';
    } else if (buildingType == 'school' || buildingType == 'university' || buildingType == 'college') {
      return 'education';
    } else if (buildingType == 'hospital' || buildingType == 'healthcare') {
      return 'healthcare';
    } else if (buildingType == 'public' || buildingType == 'government' || buildingType == 'civic') {
      return 'public';
    } else if (buildingType == 'historic' || buildingType == 'monument') {
      return 'historic';
    }
    
    return buildingType;
  }
  
  // Helper method to get building height from tags
  double _getBuildingHeight(Map<String, dynamic> tags) {
    // Default height if not specified
    double height = 10.0;
    
    // Parse height from tags if available
    if (tags.containsKey('height')) {
      try {
        height = double.parse(tags['height'] as String);
      } catch (e) {
        // If parse fails, use default height
      }
    } else if (tags.containsKey('building:levels')) {
      try {
        // Approximate 3 meters per level
        height = double.parse(tags['building:levels'] as String) * 3.0;
      } catch (e) {
        // If parse fails, use default height
      }
    }
    
    // Adjust height for special building types
    final String buildingType = tags['building'] ?? 'yes';
    if (buildingType == 'cathedral' || buildingType == 'church') {
      height = height * 1.5;
    } else if (buildingType == 'skyscraper') {
      height = height * 2.0;
    }
    
    return height;
  }
  
  // Gets the roof color based on building type and theme
  Color _getRoofColor(Map<String, dynamic> tags) {
    final String buildingType = _getBuildingType(tags);
    
    // Get the color map for the current theme, or fall back to vibrant theme
    final Map<String, Map<String, Color>>? themeColors = _buildingColorPalette[theme];
    if (themeColors == null) {
      return _buildingColorPalette['vibrant']?['default']?['roof'] ?? const Color(0xFF9E9E9E);
    }
    
    // Return specific color for the building type or default
    return themeColors[buildingType]?['roof'] ?? themeColors['default']?['roof'] ?? const Color(0xFF9E9E9E);
  }
  
  // Draw enhanced building with shadows, gradients, and lighting effects
  void _drawEnhancedBuilding(
    Canvas canvas, 
    Path basePath, 
    double height, 
    Color wallColor, 
    Color roofColor, 
    List<Offset> points,
    double zoomLevel,
    Map<String, dynamic> tags,
  ) {
    // Skip if too small
    if (height < 1.0 || points.length < 3) return;
    
    // Calculate projected height based on zoom and tilt
    final double projectedHeight = height * tiltFactor * (0.12 + (zoomLevel - 15) * 0.04);
    
    // Calculate extruded points (top points)
    final List<Offset> topPoints = points.map((p) => 
      Offset(p.dx, p.dy - projectedHeight)
    ).toList();
    
    // Calculate centroid (building center point)
    Offset centroid = Offset.zero;
    for (final point in points) {
      centroid += point;
    }
    centroid = Offset(centroid.dx / points.length, centroid.dy / points.length);
    
    // Get theme-based shadow settings
    double shadowOpacity = 0.4;
    double shadowSpread = 12.0;
    if (theme == 'dark') {
      shadowOpacity = 0.3;
      shadowSpread = 15.0;
    } else if (theme == 'monochrome') {
      shadowOpacity = 0.5;
      shadowSpread = 18.0;
    }
    
    // Draw base shadow (for more realistic shading)
    if (projectedHeight > 2.0) {
      // Create shadow path (same as base path but slightly larger)
      final Path shadowPath = Path();
      shadowPath.addPath(basePath, Offset.zero);
      
      // Draw shadow
      final Paint shadowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, 0.0),
          radius: 1.0,
          colors: [
            Colors.black.withOpacity(shadowOpacity),
            Colors.black.withOpacity(0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: centroid, 
            radius: shadowSpread + (projectedHeight * 0.5),
          ),
        );
      
      canvas.drawPath(shadowPath, shadowPaint);
    }
    
    // Draw the roof first so it gets partially covered by the walls
    final Path roofPath = Path();
    roofPath.addPolygon(topPoints, true);
    
    // Get sun direction (for lighting)
    // In a real app, this could be based on actual time of day
    const double sunAngle = math.pi * 1.25; // 45 degrees from top-right
    
    // Roof gradient based on sunlight angle
    final Gradient roofGradient = LinearGradient(
      begin: Alignment(math.cos(sunAngle), math.sin(sunAngle)),
      end: Alignment(-math.cos(sunAngle), -math.sin(sunAngle)),
      colors: [
        roofColor.withOpacity(0.95),
        roofColor.withOpacity(0.7),
      ],
    );
    
    // Draw roof
    final Paint roofPaint = Paint()
      ..shader = roofGradient.createShader(
        Rect.fromPoints(
          topPoints.reduce((a, b) => a.dx < b.dx ? a : b),
          topPoints.reduce((a, b) => a.dx > b.dx ? a : b),
        ),
      );
    
    canvas.drawPath(roofPath, roofPaint);
    
    // Add subtle roof outline
    final Paint roofOutlinePaint = Paint()
      ..color = roofColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    canvas.drawPath(roofPath, roofOutlinePaint);
    
    // Draw walls between each pair of points
    for (int i = 0; i < points.length; i++) {
      final int nextIndex = (i + 1) % points.length;
      
      final Offset p1 = points[i];
      final Offset p2 = points[nextIndex];
      final Offset p3 = topPoints[nextIndex];
      final Offset p4 = topPoints[i];
      
      // Skip if points too close (degenerate wall)
      if ((p1 - p2).distance < 1.0) continue;
      
      // Create wall path
      final Path wallPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();
      
      // Calculate wall angle for dynamic lighting
      final double wallAngle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      
      // Calculate lighting factor based on angle to sun
      final double angleToSun = (wallAngle - sunAngle) % (math.pi * 2);
      final double normalizedAngleToSun = angleToSun > math.pi ? 2 * math.pi - angleToSun : angleToSun;
      final double lightingFactor = 0.5 + 0.5 * math.cos(normalizedAngleToSun);
      
      // Apply lighting to wall color
      Color lightedWallColor = wallColor;
      if (lightingFactor > 0.7) {
        // Brighten wall facing the sun
        lightedWallColor = _brightenColor(wallColor, (lightingFactor - 0.7) * 2.0);
      } else if (lightingFactor < 0.3) {
        // Darken wall facing away from sun
        lightedWallColor = _darkenColor(wallColor, (0.3 - lightingFactor) * 2.0);
      }
      
      // Create wall gradient based on lighting
      final Gradient wallGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lightedWallColor.withOpacity(0.95),
          lightedWallColor.withOpacity(0.85),
        ],
      );
      
      // Draw wall with gradient
      final Paint wallPaint = Paint()
        ..shader = wallGradient.createShader(
          Rect.fromPoints(p4, p1),
        );
      
      canvas.drawPath(wallPath, wallPaint);
      
      // Add subtle edge highlights
      final Paint edgePaint = Paint()
        ..color = lightedWallColor.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      
      canvas.drawPath(wallPath, edgePaint);
      
      // Add windows on walls if building is big enough and zoom level is sufficient
      if (projectedHeight >= 5.0 && zoomLevel >= 16.0 && (p1 - p2).distance >= 8.0) {
        _addWindowsToWall(
          canvas, 
          p1, p2, p4, p3, 
          projectedHeight, 
          wallColor, 
          tags,
        );
      }
    }
    
    // Draw base outline
    final Paint outlinePaint = Paint()
      ..color = wallColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    canvas.drawPath(basePath, outlinePaint);
  }
  
  // Helper method to add windows to walls
  void _addWindowsToWall(
    Canvas canvas, 
    Offset bottom1, 
    Offset bottom2, 
    Offset top1, 
    Offset top2,
    double projectedHeight,
    Color baseColor,
    Map<String, dynamic> tags,
  ) {
    // Calculate wall width and height
    final double wallWidth = (bottom2 - bottom1).distance;
    final double wallHeight = projectedHeight;
    
    // Skip small walls
    if (wallWidth < 10.0 || wallHeight < 6.0) return;
    
    // Calculate window spacing
    final int floorsCount = math.max(1, (wallHeight / 4.0).floor());
    final int windowsPerRow = math.max(1, (wallWidth / 6.0).floor());
    
    // Adjust window size based on zoom
    final double windowWidth = math.min(5.0, (wallWidth / windowsPerRow) * 0.7);
    final double windowHeight = math.min(3.0, (wallHeight / floorsCount) * 0.7);
    
    // Window margin
    final double hMargin = (wallWidth - (windowWidth * windowsPerRow)) / (windowsPerRow + 1);
    final double vMargin = (wallHeight - (windowHeight * floorsCount)) / (floorsCount + 1);
    
    // Calculate wall direction and perpendicular vector for proper window placement
    final Offset wallDirection = (bottom2 - bottom1).normalize();
    final Offset wallPerp = Offset(-wallDirection.dy, wallDirection.dx);
    
    // Window colors - night vs day
    final DateTime now = DateTime.now();
    final bool isNight = now.hour < 6 || now.hour > 18;
    
    // Generate random window patterns based on building type
    final String buildingType = tags['building'] ?? 'yes';
    bool hasUniformWindows = buildingType == 'office' || 
                           buildingType == 'commercial' || 
                           buildingType == 'apartments';
    
    // Window colors
    Color windowColor;
    Color windowLitColor;
    
    if (isNight) {
      // Night colors
      windowColor = const Color(0xFF1F2937);
      windowLitColor = const Color(0xFFFFE082).withOpacity(0.85);
    } else {
      // Day colors - slight blue tint for glass reflection
      windowColor = const Color(0xFF90CAF9).withOpacity(0.7);
      windowLitColor = const Color(0xFFFFFFFF).withOpacity(0.9);
    }
    
    // Window paint
    final Paint windowPaint = Paint()
      ..color = windowColor;
    
    // Window light paint - with radial gradient for glow effect
    final Paint windowLitPaint = Paint()
      ..color = windowLitColor;
    
    // Determine window probability
    double litProbability = isNight ? 0.3 : 0.05;
    
    // Different patterns for different building types
    if (buildingType == 'office') {
      litProbability = isNight ? 0.5 : 0.2;
    } else if (buildingType == 'residential') {
      litProbability = isNight ? 0.4 : 0.1;
    }
    
    // Draw windows
    for (int floor = 0; floor < floorsCount; floor++) {
      for (int win = 0; win < windowsPerRow; win++) {
        // Offset from bottom-left of wall
        final double xOffset = hMargin + win * (windowWidth + hMargin);
        final double yOffset = vMargin + floor * (windowHeight + vMargin);
        
        // Start position (offset from bottom1 along wall direction)
        final Offset startPos = bottom1 + (wallDirection * xOffset);
        
        // Window position (offset upward perpendicular to wall)
        final Offset windowPos = startPos - (wallPerp * (yOffset + windowHeight));
        
        // Create window rect
        final Rect windowRect = Rect.fromLTWH(
          windowPos.dx, 
          windowPos.dy, 
          windowWidth, 
          windowHeight
        );
        
        // Randomly decide if window is lit
        final bool isLit = _random.nextDouble() < litProbability;
        
        // Draw window
        if (hasUniformWindows) {
          // Regular window pattern for office/commercial buildings
          canvas.drawRect(windowRect, isLit ? windowLitPaint : windowPaint);
        } else {
          // More varied windows for other buildings
          final double cornerRadius = windowHeight * 0.2;
          final RRect roundedRect = RRect.fromRectAndRadius(
            windowRect, 
            Radius.circular(cornerRadius)
          );
          canvas.drawRRect(roundedRect, isLit ? windowLitPaint : windowPaint);
        }
      }
    }
  }
  
  // Helper methods for color manipulation
  Color _brightenColor(Color color, double factor) {
    // Increase color brightness
    final double amount = factor * 60;
    return Color.fromARGB(
      color.alpha,
      math.min(255, color.red + amount.toInt()),
      math.min(255, color.green + amount.toInt()),
      math.min(255, color.blue + amount.toInt()),
    );
  }
  
  Color _darkenColor(Color color, double factor) {
    // Decrease color brightness
    final double amount = factor * 40;
    return Color.fromARGB(
      color.alpha,
      math.max(0, color.red - amount.toInt()),
      math.max(0, color.green - amount.toInt()),
      math.max(0, color.blue - amount.toInt()),
    );
  }
  
  @override
  bool shouldRepaint(covariant OSMBuildingsPainter oldDelegate) {
    return oldDelegate.buildings != buildings ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.visibleBounds != visibleBounds ||
           oldDelegate.theme != theme;
  }
} 