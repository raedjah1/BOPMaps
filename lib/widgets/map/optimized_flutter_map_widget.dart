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
import 'user_location_marker.dart';
import 'map_styles.dart';

// New optimized components
import 'optimized_map_controller.dart';
import 'map_caching/optimized_tile_provider.dart';
import 'map_caching/zoom_level_manager.dart';
import 'map_caching/multi_level_renderer.dart';
import '../../services/map_cache_manager.dart';
import 'map_caching/data_downloader.dart';
import 'zoom_level_navigator.dart';
import 'map_caching/map_cache_extension.dart';

// New control widgets
import 'controls/map_controls.dart';

/// An optimized version of the FlutterMapWidget that uses advanced caching
/// and multi-level zoom techniques for superior performance.
class OptimizedFlutterMapWidget extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(Map<String, dynamic>) onPinTap;

  const OptimizedFlutterMapWidget({
    Key? key,
    required this.mapProvider,
    required this.onPinTap,
  }) : super(key: key);

  @override
  OptimizedFlutterMapWidgetState createState() => OptimizedFlutterMapWidgetState();
}

class OptimizedFlutterMapWidgetState extends State<OptimizedFlutterMapWidget> with TickerProviderStateMixin {
  // Optimized controllers and managers
  late OptimizedMapController _optimizedController;
  final PopupController _popupController = PopupController();
  final ZoomLevelManager _zoomManager = ZoomLevelManager();
  final MapCacheManager _cacheManager = MapCacheManager();
  final DataDownloader _dataDownloader = DataDownloader();
  
  // Variables for the 2.5D effect
  double _tiltAngle = MapStyles.defaultTiltAngle;
  double _rotationAngle = MapStyles.defaultRotationAngle;
  late AnimationController _animationController;
  late Animation<double> _tiltAnimation;
  
  // State tracking
  bool _isMapMoving = false;
  double _currentZoom = AppConstants.defaultZoom;
  LatLng _currentCenter = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  LatLngBounds _visibleBounds = LatLngBounds(
    LatLng(AppConstants.defaultLatitude - 0.05, AppConstants.defaultLongitude - 0.05),
    LatLng(AppConstants.defaultLatitude + 0.05, AppConstants.defaultLongitude + 0.05)
  );
  int _currentZoomLevel = 3; // Default to Regional view
  
  // UI state
  bool _showZoomControls = true;
  bool _showZoomLevelNavigator = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  // Timer to debounce map movement for performance
  Timer? _mapMovementDebounceTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _optimizedController = OptimizedMapController();
    
    // Set up animation controller for tilt effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _tiltAnimation = Tween<double>(
      begin: 0.0,
      end: _tiltAngle,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    // Listen for zoom level changes
    _optimizedController.addZoomLevelChangeListener(_handleZoomLevelChange);
    _optimizedController.addMoveStateListener(_handleMoveStateChange);
    
    // Listen for download status changes
    _listenForDownloadStatus();
  }
  
  void _handleZoomLevelChange(int level) {
    if (level != _currentZoomLevel) {
      setState(() {
        _currentZoomLevel = level;
      });
      
      // Jump to the appropriate zoom for this level using the controller
      _optimizedController.jumpToZoomLevel(level);
      
      // Show a visual indicator that zoom level has changed
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_getZoomLevelName()}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void _handleMoveStateChange(bool isMoving) {
    setState(() {
      _isMapMoving = isMoving;
    });
  }
  
  void _listenForDownloadStatus() {
    // Set up a timer to periodically check download status
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final isDownloading = _dataDownloader.isDownloading;
      final progress = _dataDownloader.downloadProgress;
      
      if (isDownloading != _isDownloading || 
          (isDownloading && (progress - _downloadProgress).abs() > 0.01)) {
        setState(() {
          _isDownloading = isDownloading;
          _downloadProgress = progress;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _optimizedController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            FlutterMap(
              mapController: _optimizedController.mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  AppConstants.defaultLatitude,
                  AppConstants.defaultLongitude
                ),
                initialZoom: AppConstants.defaultZoom,
                minZoom: 2.0,
                maxZoom: 19.0,
                onMapEvent: _handleMapEvent,
                rotation: _rotationAngle,
                interactionOptions: const InteractionOptions(
                  enableScrollWheel: true,
                  enableMultiFingerGestureRace: true,
                  flags: InteractiveFlag.all,
                ),
                maxBounds: null,
              ),
              children: [
                // Base map tiles with optimized provider
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  tileProvider: _optimizedController.getOptimizedTileProvider(
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
                  ),
                  backgroundColor: Colors.grey[300],
                  tileBuilder: _buildOptimizedTile,
                  maxZoom: 19,
                  minZoom: 2,
                ),
                
                // Multi-level renderer for OSM features
                MultiLevelRenderer(
                  visibleBounds: _visibleBounds,
                  zoomLevel: _currentZoom,
                  isMapMoving: _isMapMoving,
                  tiltFactor: _tiltAnimation.value,
                  theme: widget.mapProvider.mapTheme,
                ),
                
                // Marker layers
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    disableClusteringAtZoom: 16,
                    size: const Size(40, 40),
                    markers: _createMarkers(),
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: MapStyles.primaryColor.withOpacity(0.7),
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
                
                // User location marker (if location available)
                if (widget.mapProvider.currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        height: 60,
                        width: 60,
                        point: LatLng(
                          widget.mapProvider.currentPosition!.latitude,
                          widget.mapProvider.currentPosition!.longitude,
                        ),
                        child: const UserLocationMarker(
                          accuracy: 20.0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            // UI controls using separated widgets
            ZoomLevelInfoCard(currentZoomLevel: _currentZoomLevel),
            
            MapZoomControls(
              mapController: _optimizedController,
              currentCenter: _currentCenter,
              currentZoom: _currentZoom,
              toggleTilt: _toggleTilt,
              isLocationTracking: widget.mapProvider.isLocationTracking,
              currentPosition: widget.mapProvider.currentPosition,
              toggleLocationTracking: widget.mapProvider.toggleLocationTracking,
              downloadCurrentArea: _downloadCurrentArea,
              toggleZoomLevelNavigator: _toggleZoomLevelNavigator,
              showZoomLevelNavigator: _showZoomLevelNavigator,
            ),
            
            if (_showZoomLevelNavigator)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: ZoomLevelNavigator(
                    mapController: _optimizedController,
                    onZoomLevelChanged: _handleZoomLevelChange,
                  ),
                ),
              ),
            
            DownloadProgressIndicator(
              isDownloading: _isDownloading,
              downloadProgress: _downloadProgress,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildZoomLevelInfoCard() {
    return AnimatedOpacity(
      opacity: _currentZoomLevel == 0 ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getZoomLevelIcon(),
              color: MapStyles.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _getZoomLevelName(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getZoomLevelIcon() {
    switch (_currentZoomLevel) {
      case 1: return Icons.public;
      case 2: return Icons.map;
      case 3: return Icons.location_city;
      case 4: return Icons.location_on;
      case 5: return Icons.streetview;
      default: return Icons.map;
    }
  }
  
  String _getZoomLevelName() {
    switch (_currentZoomLevel) {
      case 1: return 'World View';
      case 2: return 'Continental View';
      case 3: return 'Regional View';
      case 4: return 'Local Area View';
      case 5: return 'Street View';
      default: return 'Map View';
    }
  }
  
  // Optimized tile builder
  Widget _buildOptimizedTile(BuildContext context, Widget tile, TileImage tileImage) {
    // Apply different rendering based on zoom level
    switch (_currentZoomLevel) {
      case 1: // World view
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFE3F2FD), // Light blue tint
            BlendMode.overlay,
          ),
          child: tile,
        );
      
      case 2: // Continental view
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFE8F5E9), // Light green tint
            BlendMode.overlay,
          ),
          child: tile,
        );
      
      default:
        return tile;
    }
  }
  
  // Handle map events
  void _handleMapEvent(MapEvent event) {
    // Track current map state
    _currentZoom = _optimizedController.mapController.camera.zoom;
    _currentCenter = _optimizedController.mapController.camera.center;
    _visibleBounds = _optimizedController.mapController.camera.visibleBounds;
    
    // Update zoom level manager with current zoom
    _zoomManager.updateZoomLevel(_currentZoom);
    
    // Get the new zoom level from the manager
    final newZoomLevel = _zoomManager.currentZoomLevel;
    if (newZoomLevel != _currentZoomLevel) {
      setState(() {
        _currentZoomLevel = newZoomLevel;
      });
    }
    
    // Throttle updates during continuous movement
    if (event is MapEventMoveStart) {
      setState(() {
        _isMapMoving = true;
      });
    } else if (event is MapEventMoveEnd) {
      setState(() {
        _isMapMoving = false;
      });
      
      // After movement ends, ensure zoom level is properly synced
      final finalZoomLevel = _zoomManager.currentZoomLevel;
      if (finalZoomLevel != _currentZoomLevel) {
        setState(() {
          _currentZoomLevel = finalZoomLevel;
        });
      }
    }
    
    // Reset debounce timer to prevent excessive UI updates
    _mapMovementDebounceTimer?.cancel();
    _mapMovementDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          // Update bounds for visible area calculations
          _zoomManager.updateBounds(_visibleBounds);
        });
      }
    });
  }
  
  // Download current visible area
  void _downloadCurrentArea() async {
    if (_isDownloading) {
      // Already downloading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A download is already in progress'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Confirm with user
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Map Data'),
        content: const Text(
          'Download this area for offline use? This will use approximately 10-20MB of storage depending on the size of the area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    
    if (shouldDownload == true) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });
      
      final result = await _optimizedController.downloadCurrentArea();
      
      setState(() {
        _isDownloading = false;
      });
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Area downloaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download area'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // Toggle the tilt effect
  void _toggleTilt() {
    setState(() {
      if (_tiltAngle > 0) {
        // Switch to 2D
        _tiltAngle = 0;
        _optimizedController.toggle3DMode();
      } else {
        // Switch to 3D
        _tiltAngle = MapStyles.defaultTiltAngle;
        _optimizedController.toggle3DMode();
      }
      
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
  
  // Create markers from the provider's pins
  List<Marker> _createMarkers() {
    return widget.mapProvider.pins.map((pin) {
      return Marker(
        height: 60,
        width: 40,
        point: LatLng(pin['latitude'], pin['longitude']),
        child: GestureDetector(
          onTap: () => widget.onPinTap(pin),
          child: const MapPinWidget(),
        ),
      );
    }).toList();
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
  
  // Public methods to control the map externally
  void resetMapView() {
    setState(() {
      _rotationAngle = MapStyles.defaultRotationAngle;
      _toggleTilt();
    });
  }
  
  void animateToLocation(double latitude, double longitude, {double? zoom}) {
    _optimizedController.animateTo(
      location: LatLng(latitude, longitude),
      zoom: zoom ?? AppConstants.defaultZoom,
      duration: const Duration(milliseconds: 500),
    );
  }
  
  void jumpToZoomLevel(int level) {
    _optimizedController.jumpToZoomLevel(level);
  }
  
  // Method to toggle zoom level navigator visibility
  void _toggleZoomLevelNavigator() {
    setState(() {
      _showZoomLevelNavigator = !_showZoomLevelNavigator;
    });
  }
} 