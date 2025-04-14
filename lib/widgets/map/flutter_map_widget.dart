import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:async';

import '../../config/constants.dart';
import '../../providers/map_provider.dart';
import 'map_pin_widget.dart';
import 'map_layers/terrain_layer.dart';
import 'map_layers/buildings_layer.dart';
import 'map_layers/trees_layer.dart';
import 'map_layers/osm_buildings_layer.dart';
import 'map_layers/osm_roads_layer.dart';
import 'map_layers/osm_data_processor.dart';
import 'map_layers/osm_water_features_layer.dart';
import 'map_layers/osm_parks_layer.dart';
import 'user_location_marker.dart';
import 'map_styles.dart';

class FlutterMapWidget extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(Map<String, dynamic>) onPinTap;

  const FlutterMapWidget({
    Key? key,
    required this.mapProvider,
    required this.onPinTap,
  }) : super(key: key);

  @override
  FlutterMapWidgetState createState() => FlutterMapWidgetState();
}

// Make the class public but keep the original name for compatibility
class FlutterMapWidgetState extends State<FlutterMapWidget> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  
  // Variables for the 2.5D effect
  double _tiltAngle = MapStyles.defaultTiltAngle; // Use consistent tilt from styles
  double _rotationAngle = MapStyles.defaultRotationAngle; // Use consistent rotation from styles
  late AnimationController _animationController;
  late Animation<double> _tiltAnimation;
  
  // Public accessor for tilt animation value
  Animation<double> get tiltAnimation => _tiltAnimation;
  
  // Animation controllers for smooth movement
  AnimationController? _moveAnimationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _zoomAnimation;

  // Building detail level - initialize with a default
  int _buildingDetailLevel = 3; // Changed from 2 to 3 for high detail
  bool _isMapInitialized = false;
  bool _isFirstLoad = true;
  
  // Flag to toggle between decorative and real OSM 2.5D layers
  bool _useRealOSMData = true; // Changed from false to true to use real data by default
  
  // Flag to handle fallback tiles
  bool _isUsingFallbackTiles = false;
  
  // Track if map is currently moving for responsive layer updates
  bool _isMapMoving = false;
  double _currentZoom = 16.0; // Changed from AppConstants.defaultZoom to 16.0
  LatLng _currentCenter = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  LatLngBounds _visibleBounds = LatLngBounds(
    LatLng(AppConstants.defaultLatitude - 0.05, AppConstants.defaultLongitude - 0.05),
    LatLng(AppConstants.defaultLatitude + 0.05, AppConstants.defaultLongitude + 0.05)
  );
  
  // Timer to debounce map movement for performance
  Timer? _mapMovementDebounceTimer;
  
  // Suppress initial error messages and provide retry functionality
  bool _initialLoadAttempted = false;
  bool _mapLoadFailed = false;
  
  // Add a state variable to track when we're getting user location
  bool _isGettingUserLocation = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize the animation controller for tilt effect
    _animationController = AnimationController(
      duration: MapStyles.tiltAnimationDuration,
      vsync: this,
    );
    
    // Create a tilt animation
    _tiltAnimation = Tween<double>(
      begin: 0.0,
      end: _tiltAngle,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start the animation
    _animationController.forward();
    
    // Listen for map events
    _mapController.mapEventStream.listen(_handleMapEvent);
    
    // Force initial state setup without waiting for the first map event
    _isMapInitialized = true;
    
    // Schedule a post-frame callback to update the map position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Use user's current position if available, otherwise use default
        final LatLng initialPosition;
        if (widget.mapProvider.currentPosition != null) {
          initialPosition = LatLng(
            widget.mapProvider.currentPosition!.latitude,
            widget.mapProvider.currentPosition!.longitude
          );
          debugPrint('Using user\'s current location: ${initialPosition.latitude}, ${initialPosition.longitude}');
        } else {
          // If user location is not available, request it first
          _requestUserLocation().then((userLocation) {
            if (mounted && userLocation != null) {
              // Move map to user location once we get it
              _mapController.move(userLocation, 16.0);
              _currentCenter = userLocation;
              setState(() {});
              debugPrint('Moved map to delayed user location: ${userLocation.latitude}, ${userLocation.longitude}');
            }
          });
          
          // Meanwhile use default position
          initialPosition = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
          debugPrint('Using default location temporarily: ${initialPosition.latitude}, ${initialPosition.longitude}');
        }
        
        // Ensure we start at zoom level 16
        _mapController.move(initialPosition, 16.0);
        _currentCenter = initialPosition;
        
        // Force detail level to high (3)
        setState(() {
          _buildingDetailLevel = 3;
          _initialLoadAttempted = true;
          debugPrint('INITIAL MAP SETUP - Zoom: 16.0, Detail Level: 3');
        });
        
        // Add a delay to check if map loaded successfully
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isUsingFallbackTiles) {
            setState(() {
              _mapLoadFailed = true;
            });
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _moveAnimationController?.dispose();
    _mapController.dispose();
    _mapMovementDebounceTimer?.cancel();
    super.dispose();
  }
  
  // Handle map events with enhanced responsiveness
  void _handleMapEvent(MapEvent event) {
    // First load and initialization
    if (_isFirstLoad) {
      _isFirstLoad = false;
      setState(() {
        _isMapInitialized = true;
        _determineDetailLevel();
      });
    }
    
    // Track current map state for responsive layer updates
    _currentZoom = _mapController.camera.zoom;
    _currentCenter = _mapController.camera.center;
    _visibleBounds = _mapController.camera.visibleBounds;
    
    // DEBUG: Print current zoom level
    debugPrint('Current Zoom Level: ${_currentZoom.toStringAsFixed(2)}');
    
    // If we get any map events, the map has loaded successfully
    if (_mapLoadFailed) {
      setState(() {
        _mapLoadFailed = false;
      });
    }
    
    // Differentiate between event types for proper response
    if (event is MapEventMoveStart) {
      // Map movement started
      setState(() {
        _isMapMoving = true;
      });
    } else if (event is MapEventMove) {
      // Continuously update during movement (throttled for performance)
      _throttledMapUpdate();
    } else if (event is MapEventMoveEnd) {
      // Movement ended
      setState(() {
        _isMapMoving = false;
        _determineDetailLevel();
      });
    } else if (event is MapEventRotateStart || event is MapEventRotateEnd || event is MapEventRotate) {
      // Handle rotation events
      setState(() {}); // Simple redraw
    } 
    // We don't have specific zoom event types in newer flutter_map, use move events instead
  }
  
  // Throttle updates during continuous map movements for better performance
  void _throttledMapUpdate() {
    if (_mapMovementDebounceTimer?.isActive ?? false) return;
    
    _mapMovementDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          // This forces a redraw of the map layers with current bounds/zoom
        });
      }
    });
  }
  
  // Determine building and POI detail level based on zoom
  void _determineDetailLevel() {
    final zoom = _mapController.camera.zoom;
    int newLevel;
    
    if (zoom < 14.0) {
      newLevel = 1; // Low detail
    } else if (zoom < 16.0) {
      newLevel = 2; // Medium detail
    } else {
      newLevel = 3; // High detail
    }
    
    if (_buildingDetailLevel != newLevel) {
      // DEBUG: Print detail level change
      debugPrint('Zoom Level: ${zoom.toStringAsFixed(2)} - Detail Level changing from $_buildingDetailLevel to $newLevel');
      
      setState(() {
        _buildingDetailLevel = newLevel;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Create markers from pins
    final markers = _createMarkers();
    
    return AnimatedBuilder(
      animation: _tiltAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            GestureDetector(
              // Add gesture controls for tilt and rotation adjustment
              onVerticalDragUpdate: (details) {
                // Adjust tilt on vertical drag
                final newTilt = _tiltAngle - details.delta.dy * 0.01;
                // Limit tilt range for good UX
                if (newTilt >= 0 && newTilt <= MapStyles.maxTiltAngle) {
                  setState(() {
                    _tiltAngle = newTilt;
                    _tiltAnimation = Tween<double>(
                      begin: _tiltAnimation.value,
                      end: _tiltAngle,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOutCubic,
                    ));
                    _animationController.reset();
                    _animationController.forward();
                  });
                }
              },
              onHorizontalDragUpdate: (details) {
                // Adjust rotation on horizontal drag
                setState(() {
                  _rotationAngle += details.delta.dx * 0.005;
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Apply perspective transformation for the 2.5D effect
                  return Transform(
                    alignment: Alignment.center,
                    transform: _build25DMatrix(),
                    child: Container(
                      // Make container larger to accommodate for the tilt effect
                      width: constraints.maxWidth * (1 + _tiltAnimation.value * 0.3),
                      height: constraints.maxHeight * (1 + _tiltAnimation.value * 0.3),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          maxWidth: constraints.maxWidth * (1 + _tiltAnimation.value * 0.3),
                          maxHeight: constraints.maxHeight * (1 + _tiltAnimation.value * 0.3),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                PopupScope(
                                  popupController: _popupController,
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _currentCenter,
                                      initialZoom: 16.0,
                                      minZoom: 2.0, // Set lower minimum zoom to allow seeing more of the world
                                      maxZoom: 19.0, // Allow high zoom for detail
                                      onMapEvent: _handleMapEvent,
                                      // Add rotation for the map itself
                                      rotation: _rotationAngle,
                                      interactionOptions: const InteractionOptions(
                                        enableScrollWheel: true,
                                        enableMultiFingerGestureRace: true,
                                        flags: InteractiveFlag.all, // Enable all interactions
                                      ),
                                      maxBounds: null, // Remove bounds restriction
                                    ),
                                    children: [
                                      // Base tile layer (Uber-like styled map)
                                      TileLayer(
                                        urlTemplate: MapStyles.darkMapTileUrl,
                                        userAgentPackageName: 'com.example.bopmaps',
                                        backgroundColor: MapStyles.backgroundColor,
                                        retinaMode: true,
                                        tileBuilder: (context, child, tile) {
                                          return Opacity(
                                            opacity: 0.8 + (0.2 * _tiltAnimation.value),
                                            child: child,
                                          );
                                        },
                                        // Improved error handling for the TileLayer
                                        errorTileCallback: (tile, error, stackTrace) {
                                          // Don't show error popup, just log to console and use fallback
                                          debugPrint('Tile error: ${error.toString().substring(0, math.min(100, error.toString().length))} - Using fallback');
                                          if (!_isUsingFallbackTiles && mounted) {
                                            setState(() {
                                              _isUsingFallbackTiles = true;
                                            });
                                          }
                                        },
                                        // Use a different templateUrl if fallback is active
                                        errorImage: const NetworkImage('https://tile.openstreetmap.org/1/1/1.png'),
                                      ),
                                      
                                      // Fallback tile layer that only shows if primary fails
                                      if (_isUsingFallbackTiles)
                                        TileLayer(
                                          urlTemplate: MapStyles.fallbackMapTileUrl,
                                          userAgentPackageName: 'com.example.bopmaps',
                                          backgroundColor: MapStyles.backgroundColor,
                                          retinaMode: true,
                                          tileBuilder: (context, child, tile) {
                                            return Opacity(
                                              opacity: 0.8 + (0.2 * _tiltAnimation.value),
                                              child: child,
                                            );
                                          },
                                        ),
                                      
                                      // Either use real OSM data or decorative layers based on the toggle
                                      if (_useRealOSMData) ...[
                                        // Water features layer - should be rendered first (beneath everything)
                                        OSMWaterFeaturesLayer(
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _currentZoom,
                                          isMapMoving: _isMapMoving,
                                          visibleBounds: _visibleBounds,
                                          waterColor: MapStyles.primaryColor.withOpacity(0.5), // Use primary color for music theme
                                        ),
                                        
                                        // Parks and vegetation layer - rendered before roads and buildings
                                        OSMParksLayer(
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _currentZoom,
                                          isMapMoving: _isMapMoving,
                                          visibleBounds: _visibleBounds,
                                        ),
                                        
                                        // Real OSM Roads Layer with 2.5D effects
                                        OSMRoadsLayer(
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _currentZoom,
                                          isMapMoving: _isMapMoving,
                                          visibleBounds: _visibleBounds,
                                        ),
                                        
                                        // Real OSM Buildings Layer with 2.5D effects
                                        OSMBuildingsLayer(
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _currentZoom,
                                          isMapMoving: _isMapMoving,
                                          visibleBounds: _visibleBounds,
                                        ),
                                      ] else ...[
                                        // Decorative placeholder layers when not using real OSM data
                                        // We won't need these once the real OSM layers are stable
                                        TerrainLayer(
                                          tiltFactor: _tiltAnimation.value,
                                        ),
                                        TreesLayer(
                                          tiltFactor: _tiltAnimation.value,
                                        ),
                                        BuildingsLayer(
                                          tiltFactor: _tiltAnimation.value,
                                        ),
                                      ],
                                      
                                      // User location marker
                                      if (widget.mapProvider.currentPosition != null)
                                        UserLocationMarker(
                                          position: LatLng(
                                            widget.mapProvider.currentPosition!.latitude,
                                            widget.mapProvider.currentPosition!.longitude,
                                          ),
                                          heading: widget.mapProvider.currentPosition!.heading,
                                          primaryColor: Theme.of(context).primaryColor,
                                        ),
                                        
                                      // Music pins layer
                                      MarkerClusterLayerWidget(
                                        options: MarkerClusterLayerOptions(
                                          maxClusterRadius: 45,
                                          size: const Size(40, 40),
                                          padding: const EdgeInsets.all(50),
                                          markers: markers,
                                          builder: (context, markers) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: Colors.blue.withOpacity(0.7),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  markers.length.toString(),
                                                  style: const TextStyle(color: Colors.white),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      
                                      // Popup layer for pins
                                      PopupMarkerLayerWidget(
                                        options: PopupMarkerLayerOptions(
                                          markers: markers,
                                          popupController: _popupController,
                                          popupDisplayOptions: PopupDisplayOptions(
                                            builder: (_, Marker marker) => _PopupBuilder(marker: marker),
                                            snap: PopupSnap.markerTop,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Show loading indicator during map movement for a better UX
                                if (_isMapMoving && _buildingDetailLevel >= 2)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                // Map controls overlay
                                Positioned(
                                  bottom: 85,
                                  right: 16,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Tilt control
                                      MapControlButton(
                                        icon: Icons.layers,
                                        tooltip: '3D Toggle',
                                        onPressed: _toggleTilt,
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Zoom in
                                      MapControlButton(
                                        icon: Icons.add,
                                        tooltip: 'Zoom In',
                                        onPressed: () => _animateZoom(_mapController.camera.zoom + 1),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Zoom out
                                      MapControlButton(
                                        icon: Icons.remove,
                                        tooltip: 'Zoom Out',
                                        onPressed: () => _animateZoom(_mapController.camera.zoom - 1),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Toggle location tracking
                                      MapControlButton(
                                        icon: widget.mapProvider.isLocationTracking
                                          ? Icons.my_location
                                          : Icons.location_searching,
                                        tooltip: widget.mapProvider.isLocationTracking
                                          ? 'Tracking On'
                                          : 'Locate Me',
                                        onPressed: () {
                                          if (widget.mapProvider.currentPosition != null) {
                                            widget.mapProvider.toggleLocationTracking();
                                            animateToLocation(
                                              widget.mapProvider.currentPosition!.latitude,
                                              widget.mapProvider.currentPosition!.longitude,
                                              zoom: 16,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // Loading indicator overlay
                                if (widget.mapProvider.isLoading)
                                  const Center(
                                    child: Card(
                                      elevation: 4,
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                
                                // Initial map loading indicator
                                if (!_initialLoadAttempted)
                                  const Center(
                                    child: Card(
                                      elevation: 4,
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 16),
                                            Text(
                                              "Loading map...",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                // DEBUG: Zoom level indicator overlay
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Print detailed debug information
                                      debugPrint('======= MAP DEBUG INFO =======');
                                      debugPrint('Zoom Level: ${_currentZoom.toStringAsFixed(4)}');
                                      debugPrint('Center: ${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}');
                                      debugPrint('Bounds: SW(${_visibleBounds.southWest.latitude.toStringAsFixed(6)}, ${_visibleBounds.southWest.longitude.toStringAsFixed(6)}) - NE(${_visibleBounds.northEast.latitude.toStringAsFixed(6)}, ${_visibleBounds.northEast.longitude.toStringAsFixed(6)})');
                                      debugPrint('Detail Level: $_buildingDetailLevel');
                                      debugPrint('Tilt Angle: ${_tiltAngle.toStringAsFixed(2)} (${(_tiltAngle * 57.3).toStringAsFixed(0)}°)');
                                      debugPrint('Rotation: ${_rotationAngle.toStringAsFixed(2)} (${(_rotationAngle * 57.3).toStringAsFixed(0)}°)');
                                      debugPrint('Map Moving: $_isMapMoving');
                                      debugPrint('Using fallback tiles: $_isUsingFallbackTiles');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'Zoom: ${_currentZoom.toStringAsFixed(2)} | Detail: $_buildingDetailLevel',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Location loading indicator
                                if (_isGettingUserLocation)
                                  Positioned(
                                    top: 60,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Card(
                                        color: Colors.blue.shade50,
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                "Getting your location...",
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Error message overlay - Only show for non-initial errors
            if (widget.mapProvider.hasNetworkError && _initialLoadAttempted && !_mapLoadFailed)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      widget.mapProvider.errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // Retry button for map loading failures
            if (_mapLoadFailed)
              Positioned(
                bottom: 120,
                left: 50,
                right: 50,
                child: Card(
                  color: Colors.blue.shade100,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: _retryMapLoading,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Map loading seems slow",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                "Tap to retry",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  // Toggle 3D tilt effect
  void _toggleTilt() {
    final newTiltAngle = _tiltAngle > 0.1 ? 0.0 : MapStyles.defaultTiltAngle;
    
    setState(() {
      _tiltAngle = newTiltAngle;
      _tiltAnimation = Tween<double>(
        begin: _tiltAnimation.value,
        end: _tiltAngle,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ));
      
      _animationController.reset();
      _animationController.forward();
    });
  }

  // Public accessor for toggle tilt
  void toggleTilt() => _toggleTilt();

  // Animate zoom level with smooth transition
  void _animateZoom(double targetZoom) {
    if (targetZoom < 2) targetZoom = 2;
    if (targetZoom > 19) targetZoom = 19;
    
    final currentZoom = _mapController.camera.zoom;
    final currentCenter = _mapController.camera.center;
    
    // Set up animation controller
    _moveAnimationController?.dispose();
    _moveAnimationController = AnimationController(
      duration: MapStyles.zoomAnimationDuration,
      vsync: this,
    );
    
    // Create animation for zoom
    _zoomAnimation = Tween<double>(
      begin: currentZoom,
      end: targetZoom,
    ).animate(CurvedAnimation(
      parent: _moveAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    // Update map on animation frame
    _moveAnimationController!.addListener(() {
      if (_zoomAnimation != null) {
        _mapController.move(currentCenter, _zoomAnimation!.value);
      }
    });
    
    _moveAnimationController!.forward();
  }
  
  // Build the 2.5D perspective transformation matrix
  Matrix4 _build25DMatrix() {
    // Get the current tilt from animation
    final tilt = _tiltAnimation.value;
    
    // Start with an identity matrix
    final matrix = Matrix4.identity();
    
    // Apply perspective
    const perspective = 0.001;
    final perspectiveMatrix = Matrix4.identity()
      ..setEntry(3, 2, perspective);
    matrix.multiply(perspectiveMatrix);
    
    // Apply rotation around X axis for tilt effect
    matrix.rotateX(tilt);
    
    return matrix;
  }
  
  // Public method to reset the map view that can be called from outside
  void resetMapView() {
    setState(() {
      _rotationAngle = MapStyles.defaultRotationAngle;
      _toggleTilt();
    });
  }
  
  // Public method to animate to a location
  void animateToLocation(double latitude, double longitude, {double? zoom}) {
    final targetZoom = zoom ?? AppConstants.defaultZoom;
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    
    // Clean up previous animation if it exists
    _moveAnimationController?.dispose();
    _moveAnimationController = AnimationController(
      duration: MapStyles.cameraMoveAnimationDuration,
      vsync: this,
    );
    
    // Create animations for lat, lng, and zoom
    _latAnimation = Tween<double>(
      begin: startCenter.latitude,
      end: latitude,
    ).animate(CurvedAnimation(
      parent: _moveAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    _lngAnimation = Tween<double>(
      begin: startCenter.longitude,
      end: longitude,
    ).animate(CurvedAnimation(
      parent: _moveAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    _zoomAnimation = Tween<double>(
      begin: startZoom,
      end: targetZoom,
    ).animate(CurvedAnimation(
      parent: _moveAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    // Update map on animation frame
    _moveAnimationController!.addListener(() {
      if (_latAnimation != null && _lngAnimation != null && _zoomAnimation != null) {
        _mapController.move(
          LatLng(_latAnimation!.value, _lngAnimation!.value),
          _zoomAnimation!.value,
        );
      }
    });
    
    _moveAnimationController!.forward();
  }
  
  // Create markers from pins in the provider
  List<Marker> _createMarkers() {
    final pins = widget.mapProvider.pins;
    
    return pins.map((pin) {
      // Convert pin to map if it's not already
      final pinData = pin is Map<String, dynamic> 
          ? pin 
          : pin.toJson();
          
      // Get coordinates
      final double lat = pinData['latitude'] ?? AppConstants.defaultLatitude;
      final double lng = pinData['longitude'] ?? AppConstants.defaultLongitude;
      
      return CustomMarker(
        point: LatLng(lat, lng),
        pinData: pinData,
        builder: (context) => GestureDetector(
          onTap: () => widget.onPinTap(pinData),
          child: MapPinWidget(
            pinData: pinData,
          ),
        ),
      );
    }).toList();
  }
  
  // Build cluster widget with enhanced visuals
  Widget _buildCluster(List<Marker> markers) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          markers.length.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Retry map loading
  void _retryMapLoading() {
    setState(() {
      _mapLoadFailed = false;
      _isUsingFallbackTiles = false;
    });
    
    // Use user's location if available
    final LatLng targetLocation;
    if (widget.mapProvider.currentPosition != null) {
      targetLocation = LatLng(
        widget.mapProvider.currentPosition!.latitude,
        widget.mapProvider.currentPosition!.longitude
      );
      debugPrint('Retrying with user location: ${targetLocation.latitude}, ${targetLocation.longitude}');
    } else {
      targetLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
      debugPrint('Retrying with default location');
      
      // Try to get user location if not available
      _requestUserLocation().then((userLocation) {
        if (mounted && userLocation != null) {
          // Move map to user location once we get it
          _mapController.move(userLocation, 16.0);
          _currentCenter = userLocation;
          setState(() {});
          debugPrint('Later moved map to user location: ${userLocation.latitude}, ${userLocation.longitude}');
        }
      });
    }
    
    // Try to reload map
    _mapController.move(targetLocation, 16.0);
    _currentCenter = targetLocation;
    
    debugPrint('RETRYING MAP LOAD - Zoom: 16.0, Detail Level: 3');
    
    // Check again after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isUsingFallbackTiles) {
        setState(() {
          _mapLoadFailed = true;
        });
      }
    });
  }

  // Helper method to request user location if not already available
  Future<LatLng?> _requestUserLocation() async {
    try {
      setState(() {
        _isGettingUserLocation = true;
      });
      
      await widget.mapProvider.requestLocationPermission();
      // Wait a moment for location to be acquired
      await Future.delayed(const Duration(seconds: 2));
      
      if (widget.mapProvider.currentPosition != null) {
        return LatLng(
          widget.mapProvider.currentPosition!.latitude,
          widget.mapProvider.currentPosition!.longitude
        );
      }
    } catch (e) {
      debugPrint('Error requesting user location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGettingUserLocation = false;
        });
      }
    }
    return null;
  }
}

// Map control button widget
class MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  
  const MapControlButton({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom marker class that includes pin data
class CustomMarker extends Marker {
  final Map<String, dynamic> pinData;
  
  CustomMarker({
    required LatLng point,
    required this.pinData,
    required Widget Function(BuildContext) builder,
    double width = 40.0,  // Increased width
    double height = 45.0, // Increased height to accommodate pin shape
    Alignment? alignment,
  }) : super(
         point: point,
         child: Builder(builder: builder),
         width: width,
         height: height,
         alignment: alignment ?? Alignment.topCenter,
       );
}

// Popup builder for the map pins
class _PopupBuilder extends StatelessWidget {
  final Marker marker;
  
  const _PopupBuilder({
    Key? key,
    required this.marker,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (marker is CustomMarker) {
      final customMarker = marker as CustomMarker;
      return _buildPinPopup(context, customMarker.pinData);
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildPinPopup(BuildContext context, Map<String, dynamic> pinData) {
    // Extract pin information
    final String title = pinData['title'] as String? ?? 'Unknown Location';
    final String description = pinData['description'] as String? ?? '';
    
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, minWidth: 150),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Get the FlutterMapWidgetState to access the onPinTap callback
                  final mapWidgetState = context.findAncestorStateOfType<FlutterMapWidgetState>();
                  if (mapWidgetState != null) {
                    mapWidgetState.widget.onPinTap(pinData);
                  }
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 