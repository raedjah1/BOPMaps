import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'optimized_map_controller.dart';
import 'map_caching/zoom_level_manager.dart';

/// A UI widget that provides controls for navigating between the 5 distinct zoom levels
/// and displays information about the current level.
class ZoomLevelNavigator extends StatefulWidget {
  final OptimizedMapController mapController;
  final Function(int)? onZoomLevelChanged;
  
  const ZoomLevelNavigator({
    Key? key,
    required this.mapController,
    this.onZoomLevelChanged,
  }) : super(key: key);

  @override
  State<ZoomLevelNavigator> createState() => _ZoomLevelNavigatorState();
}

class _ZoomLevelNavigatorState extends State<ZoomLevelNavigator> with SingleTickerProviderStateMixin {
  // Current selected zoom level
  int _currentLevel = 3; // Default to Regional view
  
  // Animation controller for transitions
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Level descriptions
  final Map<int, Map<String, dynamic>> _levelInfo = {
    1: {
      'name': 'Global View',
      'icon': Icons.public,
      'description': 'World overview without OSM data',
      'color': Colors.blue,
    },
    2: {
      'name': 'Continental View',
      'icon': Icons.map,
      'description': 'Continental regions with minimal OSM data',
      'color': Colors.green,
    },
    3: {
      'name': 'Regional View',
      'icon': Icons.location_city,
      'description': 'Medium detail with selected OSM features',
      'color': Colors.orange,
    },
    4: {
      'name': 'Local Area View',
      'icon': Icons.location_on,
      'description': 'Enhanced 2.5D projection with physics',
      'color': Colors.red,
    },
    5: {
      'name': 'Street View',
      'icon': Icons.streetview,
      'description': 'Maximum detail with all OSM features',
      'color': Colors.purple,
    },
  };
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Listen for zoom level changes
    widget.mapController.addZoomLevelChangeListener(_handleZoomLevelChange);
    
    // Set initial level from controller
    _currentLevel = widget.mapController.currentZoomLevel;
  }
  
  void _handleZoomLevelChange(int level) {
    if (level != _currentLevel) {
      setState(() {
        _currentLevel = level;
      });
      
      // Play animation
      _animationController.reset();
      _animationController.forward();
      
      // Notify callback
      if (widget.onZoomLevelChanged != null) {
        widget.onZoomLevelChanged!(level);
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLevelDisplay(),
          const SizedBox(height: 12),
          _buildLevelSelector(),
          const SizedBox(height: 8),
          Text(
            _levelInfo[_currentLevel]!['description'] as String,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLevelDisplay() {
    final levelData = _levelInfo[_currentLevel]!;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            levelData['icon'] as IconData,
            color: levelData['color'] as Color,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            levelData['name'] as String,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: levelData['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLevelSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++) _buildLevelButton(i),
      ],
    );
  }
  
  Widget _buildLevelButton(int level) {
    final isActive = level == _currentLevel;
    final levelData = _levelInfo[level]!;
    final Color levelColor = levelData['color'] as Color;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onLevelSelected(level),
        child: Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive 
                ? levelColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive 
                  ? levelColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                levelData['icon'] as IconData,
                color: isActive ? levelColor : Colors.grey,
                size: 16,
              ),
              const SizedBox(height: 4),
              Text(
                level.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? levelColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _onLevelSelected(int level) {
    if (level != _currentLevel) {
      setState(() {
        _currentLevel = level;
      });
      
      // Animate to new level
      widget.mapController.jumpToZoomLevel(level);
      
      // Play animation
      _animationController.reset();
      _animationController.forward();
      
      // Notify callback
      if (widget.onZoomLevelChanged != null) {
        widget.onZoomLevelChanged!(level);
      }
    }
  }
}

/// A tooltip that shows information about the current zoom level
class ZoomLevelTooltip extends StatelessWidget {
  final int zoomLevel;
  
  const ZoomLevelTooltip({
    Key? key,
    required this.zoomLevel,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Zoom level descriptions
    final Map<int, String> descriptions = {
      1: 'World View: Global overview without OSM data',
      2: 'Continental View: Continents with minimal OSM data',
      3: 'Regional View: Medium detail with select OSM features',
      4: 'Local Area View: Enhanced 2.5D projection with physics',
      5: 'Street View: Maximum detail with all OSM features',
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        descriptions[zoomLevel] ?? 'Unknown zoom level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
} 