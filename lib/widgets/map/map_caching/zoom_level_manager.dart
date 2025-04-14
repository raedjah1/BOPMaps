import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../map_layers/osm_data_processor.dart';
import '../../../services/map_cache_manager.dart';

/// A manager to handle different zoom levels and optimize rendering
/// based on the current zoom level and view mode.
class ZoomLevelManager {
  // Singleton instance
  static final ZoomLevelManager _instance = ZoomLevelManager._internal();
  factory ZoomLevelManager() => _instance;
  
  ZoomLevelManager._internal();
  
  // Define zoom level ranges
  // Level 1: World view (0-7) - No OSM data
  // Level 2: Continental view (8-10) - Minimal OSM data
  // Level 3: Regional view (11-13) - Select OSM features
  // Level 4: Local area 2.5D (14-16) - Enhanced with physics
  // Level 5: Fully zoomed (17+) - All OSM features
  
  // Current zoom level state
  int _currentZoomLevel = 3; // Default to Regional view
  int _currentZoomValue = 13; // Default zoom value
  bool _is2DModeActive = false; // 2D vs. 2.5D mode
  double _currentTilt = 0.5; // Default tilt
  
  // Cache of current view bounds
  LatLngBounds? _currentBounds;
  
  // Callbacks for view changes
  Function(int)? _onZoomLevelChanged;
  Function(bool)? _on2DModeChanged;
  Function(double)? _onTiltChanged;
  
  // Dependencies
  final MapCacheManager _cacheManager = MapCacheManager();
  final OSMDataProcessor _dataProcessor = OSMDataProcessor();
  
  // Getters
  int get currentZoomLevel => _currentZoomLevel;
  int get currentZoomValue => _currentZoomValue;
  bool get is2DModeActive => _is2DModeActive;
  double get currentTilt => _currentTilt;
  LatLngBounds? get currentBounds => _currentBounds;
  
  // Set callbacks
  void setOnZoomLevelChanged(Function(int) callback) {
    _onZoomLevelChanged = callback;
  }
  
  void setOn2DModeChanged(Function(bool) callback) {
    _on2DModeChanged = callback;
  }
  
  void setOnTiltChanged(Function(double) callback) {
    _onTiltChanged = callback;
  }
  
  // Determine zoom level from map zoom value
  void updateZoomLevel(double mapZoom) {
    // Convert float zoom to integer
    final int zoomValue = mapZoom.round();
    _currentZoomValue = zoomValue;
    
    int newZoomLevel;
    if (zoomValue <= 7) {
      newZoomLevel = 1; // World view
    } else if (zoomValue <= 10) {
      newZoomLevel = 2; // Continental
    } else if (zoomValue <= 13) {
      newZoomLevel = 3; // Regional
    } else if (zoomValue <= 16) {
      newZoomLevel = 4; // Local area
    } else {
      newZoomLevel = 5; // Fully zoomed
    }
    
    if (newZoomLevel != _currentZoomLevel) {
      _currentZoomLevel = newZoomLevel;
      if (_onZoomLevelChanged != null) {
        _onZoomLevelChanged!(newZoomLevel);
      }
    }
  }
  
  // Update the current bounds
  void updateBounds(LatLngBounds bounds) {
    _currentBounds = bounds;
  }
  
  // Toggle between 2D and 2.5D modes
  void toggle2DMode() {
    _is2DModeActive = !_is2DModeActive;
    
    // Default tilt by mode
    if (_is2DModeActive) {
      _currentTilt = 0.0; // Flat for 2D
    } else {
      _currentTilt = 0.5; // Angled for 2.5D
    }
    
    if (_on2DModeChanged != null) {
      _on2DModeChanged!(_is2DModeActive);
    }
    
    if (_onTiltChanged != null) {
      _onTiltChanged!(_currentTilt);
    }
  }
  
  // Set custom tilt value
  void setTilt(double tilt) {
    if (tilt < 0.0) tilt = 0.0;
    if (tilt > 0.8) tilt = 0.8; // Maximum tilt cap for usability
    
    _currentTilt = tilt;
    
    // Update 2D mode status based on tilt
    final bool newIs2DModeActive = tilt < 0.05;
    if (newIs2DModeActive != _is2DModeActive) {
      _is2DModeActive = newIs2DModeActive;
      if (_on2DModeChanged != null) {
        _on2DModeChanged!(_is2DModeActive);
      }
    }
    
    if (_onTiltChanged != null) {
      _onTiltChanged!(_currentTilt);
    }
  }
  
  // Jump to specific zoom level
  void jumpToZoomLevel(int zoomLevel) {
    if (zoomLevel < 1) zoomLevel = 1;
    if (zoomLevel > 5) zoomLevel = 5;
    
    // Convert zoom level to zoom value
    int targetZoomValue;
    switch (zoomLevel) {
      case 1: targetZoomValue = 5; break; // World view
      case 2: targetZoomValue = 9; break; // Continental view
      case 3: targetZoomValue = 12; break; // Regional view
      case 4: targetZoomValue = 15; break; // Local area
      case 5: targetZoomValue = 18; break; // Fully zoomed
      default: targetZoomValue = 12;
    }
    
    _currentZoomLevel = zoomLevel;
    _currentZoomValue = targetZoomValue;
    
    if (_onZoomLevelChanged != null) {
      _onZoomLevelChanged!(zoomLevel);
    }
  }
  
  // Get optimized rendering parameters for the current zoom level
  Map<String, dynamic> getOptimizedRenderingParameters() {
    // Default parameters
    Map<String, dynamic> params = {
      'showBuildings': false,
      'showRoads': false,
      'showWater': false,
      'showParks': false,
      'showPOIs': false,
      'render3D': false,
      'detailLevel': 'low',
      'showLabels': false,
      'physicsEnabled': false,
      'preloadNextZoom': false,
    };
    
    // Adjust parameters based on zoom level
    switch (_currentZoomLevel) {
      case 1: // World view
        params['showWater'] = true;
        params['detailLevel'] = 'ultra-low';
        params['showLabels'] = false;
        break;
        
      case 2: // Continental view
        params['showWater'] = true;
        params['showParks'] = true;
        params['detailLevel'] = 'very-low';
        params['showLabels'] = true;
        break;
        
      case 3: // Regional view
        params['showBuildings'] = true;
        params['showRoads'] = true;
        params['showWater'] = true;
        params['showParks'] = true;
        params['render3D'] = !_is2DModeActive;
        params['detailLevel'] = 'low';
        params['showLabels'] = true;
        break;
        
      case 4: // Local area
        params['showBuildings'] = true;
        params['showRoads'] = true;
        params['showWater'] = true;
        params['showParks'] = true;
        params['showPOIs'] = true;
        params['render3D'] = !_is2DModeActive;
        params['detailLevel'] = 'medium';
        params['showLabels'] = true;
        params['physicsEnabled'] = !_is2DModeActive;
        params['preloadNextZoom'] = true;
        break;
        
      case 5: // Fully zoomed
        params['showBuildings'] = true;
        params['showRoads'] = true;
        params['showWater'] = true;
        params['showParks'] = true;
        params['showPOIs'] = true;
        params['render3D'] = !_is2DModeActive;
        params['detailLevel'] = 'high';
        params['showLabels'] = true;
        params['physicsEnabled'] = !_is2DModeActive;
        break;
    }
    
    return params;
  }
  
  // Preload data for the next zoom level
  void preloadNextZoomLevel() {
    if (_currentBounds == null) return;
    
    // Determine target zoom level
    int targetZoomLevel = _currentZoomLevel + 1;
    if (targetZoomLevel > 5) return;
    
    // Get target zoom value
    int targetZoomValue;
    switch (targetZoomLevel) {
      case 2: targetZoomValue = 9; break;
      case 3: targetZoomValue = 12; break;
      case 4: targetZoomValue = 15; break;
      case 5: targetZoomValue = 18; break;
      default: return;
    }
    
    // Preload in background
    _preloadInBackground(_currentBounds!, targetZoomValue.toDouble());
  }
  
  // Helper method for background preloading
  void _preloadInBackground(LatLngBounds bounds, double zoom) async {
    // Only preload data needed for the target zoom level
    // based on current rendering parameters
    switch (_currentZoomLevel) {
      case 1:
        // Preloading for continental view
        await _dataProcessor.fetchWaterFeaturesData(bounds.southWest, bounds.northEast);
        break;
        
      case 2:
        // Preloading for regional view
        await _dataProcessor.fetchWaterFeaturesData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchParksData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchRoadData(bounds.southWest, bounds.northEast);
        break;
        
      case 3:
        // Preloading for local area view
        await _dataProcessor.fetchBuildingData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchRoadData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchParksData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchWaterFeaturesData(bounds.southWest, bounds.northEast);
        break;
        
      case 4:
        // Preloading for fully zoomed view
        await _dataProcessor.fetchBuildingData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchRoadData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchParksData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchWaterFeaturesData(bounds.southWest, bounds.northEast);
        await _dataProcessor.fetchPOIData(bounds.southWest, bounds.northEast);
        break;
    }
  }
  
  // Get the optimal tilt factor for the current zoom level
  double getOptimalTiltFactor() {
    if (_is2DModeActive) return 0.0;
    
    switch (_currentZoomLevel) {
      case 1: return 0.0; // No tilt for world view
      case 2: return 0.2; // Slight tilt for continental
      case 3: return 0.4; // More noticeable tilt for regional
      case 4: return 0.7; // Significant tilt for local area
      case 5: return 0.8; // Maximum tilt for fully zoomed
      default: return _currentTilt;
    }
  }
} 