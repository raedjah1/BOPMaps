import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import 'zoom_level_manager.dart';
import '../map_layers/osm_buildings_layer.dart';
import '../map_layers/osm_roads_layer.dart';
import '../map_layers/osm_parks_layer.dart';
import '../map_layers/osm_water_features_layer.dart';
import '../map_layers/osm_points_of_interest_layer.dart';

/// A specialized renderer that efficiently manages different visual representations
/// across the 5 distinct zoom levels of the map.
class MultiLevelRenderer extends StatefulWidget {
  final LatLngBounds visibleBounds;
  final double zoomLevel;
  final bool isMapMoving;
  final double tiltFactor;
  final String theme;
  
  const MultiLevelRenderer({
    Key? key,
    required this.visibleBounds,
    required this.zoomLevel,
    required this.isMapMoving,
    required this.tiltFactor,
    this.theme = 'vibrant',
  }) : super(key: key);

  @override
  State<MultiLevelRenderer> createState() => _MultiLevelRendererState();
}

class _MultiLevelRendererState extends State<MultiLevelRenderer> with SingleTickerProviderStateMixin {
  // Zoom level manager
  final ZoomLevelManager _zoomManager = ZoomLevelManager();
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  Animation<double>? _fadeAnimation;
  
  // Keep track of rendered layers and their visibility
  int _activeZoomLevel = 3; // Default to regional view
  Map<String, dynamic> _renderParams = {};
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initial update
    _updateActiveZoomLevel();
  }
  
  @override
  void didUpdateWidget(MultiLevelRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update if zoom changes
    if (widget.zoomLevel != oldWidget.zoomLevel) {
      _updateActiveZoomLevel();
    }
    
    // Update bounds in the zoom manager
    _zoomManager.updateBounds(widget.visibleBounds);
    
    // Trigger preloading for the next zoom level if we're not moving
    if (!widget.isMapMoving && oldWidget.isMapMoving) {
      _zoomManager.preloadNextZoomLevel();
    }
  }
  
  void _updateActiveZoomLevel() {
    // Update zoom manager
    _zoomManager.updateZoomLevel(widget.zoomLevel);
    
    // Get the new zoom level
    final newZoomLevel = _zoomManager.currentZoomLevel;
    
    // Skip if same level
    if (newZoomLevel == _activeZoomLevel && _renderParams.isNotEmpty) {
      return;
    }
    
    // Get new rendering parameters
    final newParams = _zoomManager.getOptimizedRenderingParameters();
    
    // Animate transition if it's a significant change
    final bool needsAnimation = _activeZoomLevel != newZoomLevel && _renderParams.isNotEmpty;
    
    setState(() {
      _activeZoomLevel = newZoomLevel;
      _renderParams = newParams;
      
      if (needsAnimation) {
        // Reset and play animation
        _animationController.reset();
        _animationController.forward();
      } else {
        // Skip animation for initial load
        _animationController.value = 1.0;
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Apply different rendering strategies based on zoom level
        _buildZoomLevelLayers(),
      ],
    );
  }
  
  Widget _buildZoomLevelLayers() {
    // Calculate an effective tilt factor
    final double effectiveTilt = _renderParams['render3D'] == true 
        ? widget.tiltFactor 
        : 0.0;
    
    // Show different layer combinations based on active zoom level
    return AnimatedBuilder(
      animation: _fadeAnimation!,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation!.value,
          child: Stack(
            children: [
              // Water Features Layer (always at bottom)
              if (_renderParams['showWater'] == true)
                OSMWaterFeaturesLayer(
                  tiltFactor: effectiveTilt,
                  zoomLevel: widget.zoomLevel,
                  isMapMoving: widget.isMapMoving,
                  visibleBounds: widget.visibleBounds,
                  detailLevel: _getDetailLevel(_renderParams['detailLevel']),
                ),
              
              // Parks Layer
              if (_renderParams['showParks'] == true)
                OSMParksLayer(
                  tiltFactor: effectiveTilt,
                  zoomLevel: widget.zoomLevel,
                  isMapMoving: widget.isMapMoving,
                  visibleBounds: widget.visibleBounds,
                  detailLevel: _getDetailLevel(_renderParams['detailLevel']),
                ),
              
              // Roads Layer
              if (_renderParams['showRoads'] == true)
                OSMRoadsLayer(
                  tiltFactor: effectiveTilt,
                  zoomLevel: widget.zoomLevel,
                  isMapMoving: widget.isMapMoving,
                  visibleBounds: widget.visibleBounds,
                  detailLevel: _getDetailLevel(_renderParams['detailLevel']),
                ),
              
              // Buildings Layer
              if (_renderParams['showBuildings'] == true)
                OSMBuildingsLayer(
                  tiltFactor: effectiveTilt,
                  zoomLevel: widget.zoomLevel,
                  isMapMoving: widget.isMapMoving,
                  visibleBounds: widget.visibleBounds,
                  theme: widget.theme,
                ),
              
              // POIs Layer - only for higher zoom levels
              if (_renderParams['showPOIs'] == true)
                OSMPointsOfInterestLayer(
                  tiltFactor: effectiveTilt,
                  zoomLevel: widget.zoomLevel,
                  isMapMoving: widget.isMapMoving,
                  visibleBounds: widget.visibleBounds,
                ),
            ],
          ),
        );
      },
    );
  }
  
  // Convert string detail level to numeric value
  double _getDetailLevel(String detailLevel) {
    switch (detailLevel) {
      case 'ultra-low': return 0.2;
      case 'very-low': return 0.4;
      case 'low': return 0.6;
      case 'medium': return 0.8;
      case 'high': return 1.0;
      default: return 0.8;
    }
  }
} 