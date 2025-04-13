import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../config/constants.dart';
import '../../providers/map_provider.dart';
import 'map_pin_widget.dart';
import 'map_layers/terrain_layer.dart';
import 'map_layers/buildings_layer.dart';
import 'map_layers/trees_layer.dart';
import 'map_layers/osm_buildings_layer.dart';
import 'map_layers/osm_roads_layer.dart';
import 'map_layers/osm_data_processor.dart';
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
  int _buildingDetailLevel = 2;
  bool _isMapInitialized = false;
  bool _isFirstLoad = true;
  
  // Flag to toggle between decorative and real OSM 2.5D layers
  bool _useRealOSMData = true; // Changed from false to true to use real data by default
  
  // Flag to handle fallback tiles
  bool _isUsingFallbackTiles = false;
  
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
    _mapController.mapEventStream.listen((event) {
      // We can detect map initialization by any event
      if (_isFirstLoad) {
        _isFirstLoad = false;
        setState(() {
          _isMapInitialized = true;
          _determineDetailLevel();
        });
      }
      
      // Update detail level when map moves
      if (event is MapEventMoveEnd) {
        _determineDetailLevel();
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _moveAnimationController?.dispose();
    _mapController.dispose();
    super.dispose();
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
                                      initialCenter: LatLng(
                                        AppConstants.defaultLatitude,
                                        AppConstants.defaultLongitude
                                      ),
                                      initialZoom: AppConstants.defaultZoom,
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
                                        // Add error handling for the TileLayer
                                        errorTileCallback: (tile, error, stackTrace) {
                                          debugPrint('Tile error: $error - Using fallback tile source');
                                          // We can't use fallbackUrls directly, but we can handle errors manually
                                          // and rebuild the layer with a different URL if needed
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
                                        // Real OSM Roads Layer with 2.5D effects
                                        OSMRoadsLayer(
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _isMapInitialized ? _mapController.camera.zoom : AppConstants.defaultZoom,
                                          visibleBounds: _isMapInitialized 
                                              ? _mapController.camera.visibleBounds
                                              : LatLngBounds(
                                                  LatLng(
                                                    AppConstants.defaultLatitude - 0.05, 
                                                    AppConstants.defaultLongitude - 0.05,
                                                  ),
                                                  LatLng(
                                                    AppConstants.defaultLatitude + 0.05, 
                                                    AppConstants.defaultLongitude + 0.05,
                                                  ),
                                                ),
                                        ),
                                        
                                        // Real OSM Buildings Layer with 2.5D effects
                                        OSMBuildingsLayer(
                                          buildingBaseColor: MapStyles.buildingBaseColor,
                                          buildingTopColor: MapStyles.buildingTopColor,
                                          tiltFactor: _tiltAnimation.value,
                                          zoomLevel: _isMapInitialized ? _mapController.camera.zoom : AppConstants.defaultZoom,
                                          visibleBounds: _isMapInitialized 
                                              ? _mapController.camera.visibleBounds
                                              : LatLngBounds(
                                                  LatLng(
                                                    AppConstants.defaultLatitude - 0.05, 
                                                    AppConstants.defaultLongitude - 0.05,
                                                  ),
                                                  LatLng(
                                                    AppConstants.defaultLatitude + 0.05, 
                                                    AppConstants.defaultLongitude + 0.05,
                                                  ),
                                                ),
                                        ),
                                      ],
                                      
                                      // Markers cluster layer for pins with improved visuals
                                      MarkerClusterLayerWidget(
                                        options: MarkerClusterLayerOptions(
                                          markers: markers,
                                          builder: (context, markers) {
                                            return _buildCluster(markers);
                                          },
                                          maxClusterRadius: 60,
                                          size: const Size(48, 48),
                                          padding: const EdgeInsets.all(50),
                                          maxZoom: 16.0,
                                        ),
                                      ),
                                      
                                      // Add the user location marker if location is available
                                      if (widget.mapProvider.currentPosition != null) 
                                        UserLocationMarker(
                                          position: LatLng(
                                            widget.mapProvider.currentPosition!.latitude,
                                            widget.mapProvider.currentPosition!.longitude,
                                          ),
                                          heading: widget.mapProvider.currentPosition!.heading,
                                          primaryColor: Theme.of(context).primaryColor,
                                        ),
                                    ],
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
              
            // Error message overlay
            if (widget.mapProvider.hasNetworkError)
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
  
  void _determineDetailLevel() {
    if (_isMapInitialized) {
      final zoom = _mapController.camera.zoom;
      int newDetail;
      
      if (zoom >= 17) {
        newDetail = 3;      // High detail
      } else if (zoom >= 15) {
        newDetail = 2;      // Medium detail
      } else {
        newDetail = 1;      // Low detail
      }
      
      if (newDetail != _buildingDetailLevel) {
        setState(() {
          _buildingDetailLevel = newDetail;
        });
      }
    }
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
  
  void _handleMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      // Update map provider with new viewport
      widget.mapProvider.updateViewport(
        latitude: event.camera.center.latitude,
        longitude: event.camera.center.longitude,
        zoom: event.camera.zoom,
      );
    }
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