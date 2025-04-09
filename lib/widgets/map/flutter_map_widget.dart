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
import 'map_layers/osm_water_layer.dart';
import 'map_layers/osm_landscape_layer.dart';
import 'map_layers/osm_data_processor.dart';

class FlutterMapWidget extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(Map<String, dynamic>) onPinTap;
  final bool showWaterBodies;
  final bool showLandscapeFeatures;
  final Color waterColor;
  final Color landscapeColor;

  const FlutterMapWidget({
    Key? key,
    required this.mapProvider,
    required this.onPinTap,
    this.showWaterBodies = true,
    this.showLandscapeFeatures = true,
    this.waterColor = const Color(0xFF2A93D5),
    this.landscapeColor = const Color(0xFF62A87C),
  }) : super(key: key);

  @override
  State<FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<FlutterMapWidget> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  
  // Variables for the 2.5D effect
  double _tiltAngle = 0.35; // Initial tilt angle in radians (approx 20 degrees)
  double _rotationAngle = 0.0; // Rotation angle in radians
  late AnimationController _animationController;
  late Animation<double> _tiltAnimation;
  
  // Building detail level - initialize with a default
  int _buildingDetailLevel = 2;
  bool _isMapInitialized = false;
  bool _isFirstLoad = true;
  
  // Flag to toggle between decorative and real OSM 2.5D layers
  bool _useRealOSMData = true; // Changed from false to true to use real data by default
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the animation controller for tilt effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
                if (newTilt >= 0 && newTilt <= 0.7) {
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
              child: Transform(
                // Apply a perspective transformation for 2.5D effect
                transform: _build25DMatrix(),
                alignment: Alignment.center,
                child: Container(
                  // Add a subtle shadow to enhance the 3D effect
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4 * _tiltAnimation.value),
                        blurRadius: 30.0 * _tiltAnimation.value,
                        offset: Offset(0, 15.0 * _tiltAnimation.value),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // The actual map
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
                              // Base tile layer (modern styled map)
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.bopmaps',
                                backgroundColor: const Color(0xFF121212),
                                tileBuilder: (context, child, tile) {
                                  return Opacity(
                                    opacity: 0.8 + (0.2 * _tiltAnimation.value),
                                    child: child,
                                  );
                                },
                              ),
                              
                              // Either use real OSM data or decorative layers based on the toggle
                              if (_useRealOSMData) ...[
                                // Real OSM Landscape Layer with 2.5D effects (parks, forests)
                                if (widget.showLandscapeFeatures)
                                  OSMLandscapeLayer(
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
                                    parkColor: widget.landscapeColor,
                                    forestColor: widget.landscapeColor.withOpacity(0.8),
                                    grasslandColor: widget.landscapeColor.withOpacity(0.9),
                                  ),
                                
                                // Real OSM Water Bodies Layer with 2.5D effects (lakes, rivers)
                                if (widget.showWaterBodies)
                                  OSMWaterLayer(
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
                                    waterColor: widget.waterColor,
                                    waterHighlightColor: widget.waterColor.withOpacity(0.8),
                                    riverColor: widget.waterColor.withOpacity(0.9),
                                  ),
                                
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
                                  buildingBaseColor: const Color(0xFF323232),
                                  buildingTopColor: const Color(0xFF4A4A4A),
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
                                  maxClusterRadius: 45,
                                  size: const Size(40, 40),
                                  padding: const EdgeInsets.all(50),
                                  markers: markers,
                                  builder: (context, markers) {
                                    return _buildCluster(markers);
                                  },
                                  popupOptions: PopupOptions(
                                    popupSnap: PopupSnap.markerTop,
                                    popupController: _popupController,
                                    popupBuilder: (_, marker) {
                                      if (marker is CustomMarker) {
                                        return _buildPinPopup(marker.pinData);
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Add a gradient overlay to simulate lighting effect
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(_tiltAnimation.value * 0.15),
                                    Colors.black.withOpacity(_tiltAnimation.value * 0.25),
                                  ],
                                  stops: const [0.0, 1.0],
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
            
            // Add a tilt indicator overlay with cleaner design
            Positioned(
              top: 16,
              right: 16,
              child: _buildTiltControls(),
            ),
            
            // Add a toggle for OSM data vs decorative layers
            Positioned(
              top: 90, // Adjusted to avoid overlap with tilt controls
              right: 16,
              child: _buildDataToggle(),
            ),
            
            // Add a stylish map control panel with adjusted positioning
            Positioned(
              bottom: 16,
              right: 24, // Increased right padding
              child: _buildMapControls(),
            ),
          ],
        );
      }
    );
  }
  
  // Update building detail level based on the current zoom
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
  
  // Move map to target location
  void moveToLocation(double latitude, double longitude, {double? zoom}) {
    final targetZoom = zoom ?? AppConstants.defaultZoom;
    _mapController.move(LatLng(latitude, longitude), targetZoom);
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
  
  // Build popup for a pin with improved design
  Widget _buildPinPopup(Map<String, dynamic> pinData) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pinData['title'] ?? 'Unknown Track',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              pinData['artist'] ?? 'Unknown Artist',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pinData['rarity'] ?? 'Common',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => widget.onPinTap(pinData),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build modern UI controls for tilt adjustment
  Widget _buildTiltControls() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '2.5D View: ${(_tiltAngle / 0.7 * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Slider(
                value: _tiltAngle,
                min: 0.0,
                max: 0.7,
                onChanged: (value) {
                  setState(() {
                    _tiltAngle = value;
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
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build toggle for OSM data vs decorative layers
  Widget _buildDataToggle() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Real OSM Data',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_useRealOSMData)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Note: API errors may occur',
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Switch(
            value: _useRealOSMData,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (value) {
              setState(() {
                _useRealOSMData = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Build map control buttons with improved spacing
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMapControlButton(
          icon: Icons.add,
          onPressed: () {
            if (_isMapInitialized) {
              final currentZoom = _mapController.camera.zoom;
              if (currentZoom < AppConstants.maxZoom) {
                _mapController.move(
                  _mapController.camera.center, 
                  currentZoom + 1.0
                );
              }
            }
          },
          tooltip: 'Zoom In',
        ),
        const SizedBox(height: 12), // Increased spacing
        _buildMapControlButton(
          icon: Icons.remove,
          onPressed: () {
            if (_isMapInitialized) {
              final currentZoom = _mapController.camera.zoom;
              if (currentZoom > AppConstants.minZoom) {
                _mapController.move(
                  _mapController.camera.center, 
                  currentZoom - 1.0
                );
              }
            }
          },
          tooltip: 'Zoom Out',
        ),
        const SizedBox(height: 24), // Extra spacing before location button
        _buildMapControlButton(
          icon: Icons.my_location,
          onPressed: () {
            moveToLocation(
              AppConstants.defaultLatitude,
              AppConstants.defaultLongitude,
            );
          },
          tooltip: 'Reset Location',
        ),
        const SizedBox(height: 12), // Increased spacing
        _buildMapControlButton(
          icon: Icons.refresh,
          onPressed: () {
            setState(() {
              _rotationAngle = 0.0;
            });
          },
          tooltip: 'Reset Rotation',
        ),
      ],
    );
  }
  
  // Helper to build a map control button
  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
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