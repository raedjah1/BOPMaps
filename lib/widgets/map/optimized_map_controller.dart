import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import '../../services/map_cache_manager.dart';
import 'map_caching/map_cache_extension.dart';

import 'map_caching/zoom_level_manager.dart';
import 'map_caching/data_downloader.dart';
import 'map_caching/optimized_tile_provider.dart';

/// A specialized map controller that implements optimized caching,
/// multi-level zoom handling, and performance optimizations.
class OptimizedMapController {
  // The underlying Flutter Map controller
  final MapController _mapController = MapController();
  MapController get mapController => _mapController;
  
  // Dependencies
  final ZoomLevelManager _zoomManager = ZoomLevelManager();
  final MapCacheManager _cacheManager = MapCacheManager();
  final DataDownloader _dataDownloader = DataDownloader();
  
  // State tracking
  bool _isMoving = false;
  bool _isInitialized = false;
  
  // Current map state
  LatLng _currentCenter = LatLng(0, 0);
  double _currentZoom = 0;
  double _currentRotation = 0;
  double _currentTilt = 0;
  LatLngBounds _visibleBounds = LatLngBounds(LatLng(0, 0), LatLng(0, 0));
  
  // Event listeners
  final List<Function(double)> _zoomListeners = [];
  final List<Function(LatLng)> _moveListeners = [];
  final List<Function(double)> _rotationListeners = [];
  final List<Function(double)> _tiltListeners = [];
  final List<Function(bool)> _moveStateListeners = [];
  final List<Function(int)> _zoomLevelChangeListeners = [];
  
  // Adaptive zoom level settings
  final Map<int, double> _zoomPresets = {
    1: 5.0,  // World view
    2: 9.0,  // Continental view
    3: 12.0, // Regional view
    4: 15.0, // Local area view
    5: 18.0, // Fully zoomed view
  };
  
  // Configuration
  bool _enablePreloading = true;
  bool _enableSmartRendering = true;
  bool _use3DEffects = true;
  
  // Constructor
  OptimizedMapController() {
    // Initialize with default configuration
    _setupEventHandlers();
  }
  
  // Setup event handlers
  void _setupEventHandlers() {
    _mapController.mapEventStream.listen((event) {
      _handleMapEvent(event);
    });
  }
  
  // Handle map events
  void _handleMapEvent(MapEvent event) {
    // Update current state
    _currentCenter = _mapController.camera.center;
    _currentZoom = _mapController.camera.zoom;
    _currentRotation = _mapController.camera.rotation;
    _visibleBounds = _mapController.camera.visibleBounds;
    
    // Update zoom manager
    _zoomManager.updateZoomLevel(_currentZoom);
    _zoomManager.updateBounds(_visibleBounds);
    
    // Handle specific events
    if (event is MapEventMoveStart) {
      _isMoving = true;
      _notifyMoveStateListeners();
      
      // Cancel non-essential network requests during movement to reduce load
      _cancelNonEssentialRequests();
    }
    else if (event is MapEventMoveEnd) {
      _isMoving = false;
      _notifyMoveStateListeners();
      
      // After movement ends, check if we need to notify about zoom level changes
      int previousZoomLevel = _zoomManager.currentZoomLevel;
      _zoomManager.updateZoomLevel(_currentZoom);
      if (previousZoomLevel != _zoomManager.currentZoomLevel) {
        _notifyZoomLevelChangeListeners();
      }
      
      // Preload data for current view if enabled and movement has stopped
      if (_enablePreloading && !_isMoving) {
        _preloadCurrentView();
      }
    }
    else if (event is MapEventMove) {
      _notifyMoveListeners();
      
      // Only update zoom if it's significantly changed
      if ((_currentZoom - _mapController.camera.zoom).abs() > 0.1) {
        _currentZoom = _mapController.camera.zoom;
        _notifyZoomListeners();
        
        // Check for zoom level transitions, but don't notify during continuous zooming
        _zoomManager.updateZoomLevel(_currentZoom);
      }
    }
    
    if (!_isInitialized) {
      _isInitialized = true;
    }
  }
  
  // Cancel non-essential network requests during map movement
  void _cancelNonEssentialRequests() {
    // Implementation will depend on the network layer used
    // This could be implemented in the OptimizedTileProvider
  }
  
  // Preload data for current view
  void _preloadCurrentView() {
    // Skip if bounds are not available
    if (_visibleBounds == null) return;
    
    // Get rendering parameters for current level
    final params = _zoomManager.getOptimizedRenderingParameters();
    
    // Check if preloading is enabled for this level
    if (params['preloadNextZoom'] == true) {
      _zoomManager.preloadNextZoomLevel();
    }
    
    // Intelligently prefetch data based on movement pattern
    // and known popular regions
  }
  
  // Move the map to a specific location
  void moveTo({
    required LatLng location,
    double? zoom,
    double? rotation,
    Duration? duration,
    Curve? curve,
  }) {
    // Use smooth animation if duration is specified
    if (duration != null) {
      animateTo(
        location: location,
        zoom: zoom,
        rotation: rotation,
        duration: duration,
        curve: curve ?? Curves.easeInOut,
      );
    } else {
      // Immediate move
      _mapController.move(
        location,
        zoom ?? _currentZoom,
        offset: null,
        rotation: rotation,
      );
    }
  }
  
  // Animate to a specific location
  void animateTo({
    required LatLng location,
    double? zoom,
    double? rotation,
    required Duration duration,
    Curve curve = Curves.easeInOut,
  }) {
    // Get current state
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final startRotation = _mapController.camera.rotation;
    
    // Calculate deltas
    final deltaLat = location.latitude - startCenter.latitude;
    final deltaLng = location.longitude - startCenter.longitude;
    final deltaZoom = (zoom ?? startZoom) - startZoom;
    final deltaRotation = (rotation ?? startRotation) - startRotation;
    
    // Create animation controller
    final controller = AnimationController(
      duration: duration,
      vsync: _getTickerProvider(),
    );
    
    // Start animation
    controller.forward();
    
    // Update on each frame
    controller.addListener(() {
      final value = curve.transform(controller.value);
      
      final newLat = startCenter.latitude + deltaLat * value;
      final newLng = startCenter.longitude + deltaLng * value;
      final newZoom = startZoom + deltaZoom * value;
      final newRotation = startRotation + deltaRotation * value;
      
      _mapController.move(
        LatLng(newLat, newLng),
        newZoom,
        rotation: newRotation,
      );
    });
    
    // Clean up when done
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || 
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
  }
  
  // Get ticker provider (private helper)
  TickerProvider _getTickerProvider() {
    return _SingleTickerProvider();
  }
  
  // Jump to specific zoom level
  void jumpToZoomLevel(int level) {
    if (level < 1) level = 1;
    if (level > 5) level = 5;
    
    // Get preset zoom for this level
    final targetZoom = _zoomPresets[level] ?? 12.0;
    
    // Update zoom manager first
    _zoomManager.jumpToZoomLevel(level);
    
    // Notify listeners about the zoom level change
    for (var listener in _zoomLevelChangeListeners) {
      listener(level);
    }
    
    // Animate to target zoom
    animateTo(
      location: _currentCenter,
      zoom: targetZoom,
      duration: const Duration(milliseconds: 500),
    );
  }
  
  // Toggle between 2D and 3D views
  void toggle3DMode() {
    _use3DEffects = !_use3DEffects;
    _zoomManager.toggle2DMode();
    
    // Update tilt
    setTilt(_use3DEffects ? 0.5 : 0.0);
  }
  
  // Set tilt value (0.0 - 0.8)
  void setTilt(double tilt) {
    if (tilt < 0.0) tilt = 0.0;
    if (tilt > 0.8) tilt = 0.8;
    
    _currentTilt = tilt;
    _zoomManager.setTilt(tilt);
    _notifyTiltListeners();
  }
  
  // Clear all caches
  Future<void> clearAllCaches() async {
    await _cacheManager.clearAllCaches();
  }
  
  // Download a region for offline use
  Future<bool> downloadRegion(String regionName) {
    return _dataDownloader.downloadRegion(regionName);
  }
  
  // Download current visible area for offline use
  Future<bool> downloadCurrentArea() {
    if (_visibleBounds == null) return Future.value(false);
    
    // Create a temporary region name
    final regionName = 'Custom Region ${DateTime.now().millisecondsSinceEpoch}';
    
    // Add to predefined regions
    final RegionDescriptor = {
      'southwest': _visibleBounds.southWest,
      'northeast': _visibleBounds.northEast,
      'zoom_levels': [
        math.max(9, (_currentZoom - 2).round()),
        _currentZoom.round(),
        math.min(18, (_currentZoom + 2).round()),
      ]
    };
    
    // Download the region
    return _dataDownloader.downloadCustomRegion(regionName, RegionDescriptor);
  }
  
  // Get optimal tile provider for current configuration
  TileProvider getOptimizedTileProvider(String urlTemplate) {
    return OptimizedTileProvider(
      urlTemplate: urlTemplate,
      tileLayer: null, // Will be set by the caller
      enablePreloading: _enablePreloading,
    );
  }
  
  // Event Listeners
  void addZoomListener(Function(double) listener) {
    _zoomListeners.add(listener);
  }
  
  void addMoveListener(Function(LatLng) listener) {
    _moveListeners.add(listener);
  }
  
  void addRotationListener(Function(double) listener) {
    _rotationListeners.add(listener);
  }
  
  void addTiltListener(Function(double) listener) {
    _tiltListeners.add(listener);
  }
  
  void addMoveStateListener(Function(bool) listener) {
    _moveStateListeners.add(listener);
  }
  
  void addZoomLevelChangeListener(Function(int) listener) {
    _zoomLevelChangeListeners.add(listener);
  }
  
  // Notify listeners
  void _notifyZoomListeners() {
    for (var listener in _zoomListeners) {
      listener(_currentZoom);
    }
  }
  
  void _notifyMoveListeners() {
    for (var listener in _moveListeners) {
      listener(_currentCenter);
    }
  }
  
  void _notifyRotationListeners() {
    for (var listener in _rotationListeners) {
      listener(_currentRotation);
    }
  }
  
  void _notifyTiltListeners() {
    for (var listener in _tiltListeners) {
      listener(_currentTilt);
    }
  }
  
  void _notifyMoveStateListeners() {
    for (var listener in _moveStateListeners) {
      listener(_isMoving);
    }
  }
  
  void _notifyZoomLevelChangeListeners() {
    for (var listener in _zoomLevelChangeListeners) {
      listener(_zoomManager.currentZoomLevel);
    }
  }
  
  // Getters
  bool get isMoving => _isMoving;
  bool get isInitialized => _isInitialized;
  LatLng get center => _currentCenter;
  double get zoom => _currentZoom;
  double get rotation => _currentRotation;
  double get tilt => _currentTilt;
  LatLngBounds? get visibleBounds => _visibleBounds;
  int get currentZoomLevel => _zoomManager.currentZoomLevel;
  bool get use3DEffects => _use3DEffects;
  
  // Configuration setters
  void setEnablePreloading(bool enable) {
    _enablePreloading = enable;
  }
  
  void setEnableSmartRendering(bool enable) {
    _enableSmartRendering = enable;
  }
  
  // Dispose resources
  void dispose() {
    // Clear listeners
    _zoomListeners.clear();
    _moveListeners.clear();
    _rotationListeners.clear();
    _tiltListeners.clear();
    _moveStateListeners.clear();
    _zoomLevelChangeListeners.clear();
  }
}

// Helper class for animations
class _SingleTickerProvider extends TickerProvider {
  Ticker? _ticker;
  
  @override
  Ticker createTicker(TickerCallback onTick) {
    _ticker?.dispose();
    _ticker = Ticker(onTick);
    return _ticker!;
  }
  
  void dispose() {
    _ticker?.dispose();
  }
} 