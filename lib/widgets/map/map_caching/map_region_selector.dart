import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import '../../../utils/map_size_calculator.dart';

/// A widget that allows the user to select a rectangular region on a map
class MapRegionSelector extends StatefulWidget {
  /// Initial center of the map
  final LatLng initialCenter;
  
  /// Initial zoom level of the map
  final double initialZoom;
  
  /// Callback when the region selection changes
  final Function(LatLngBounds bounds)? onRegionChanged;
  
  /// Optional initial region
  final LatLngBounds? initialRegion;
  
  /// Maximum allowed area in square kilometers
  final double maxAreaSqKm;
  
  /// Map tile URL template
  final String urlTemplate;
  
  const MapRegionSelector({
    Key? key,
    required this.initialCenter,
    this.initialZoom = 13.0,
    this.onRegionChanged,
    this.initialRegion,
    this.maxAreaSqKm = 500.0,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  }) : super(key: key);

  @override
  State<MapRegionSelector> createState() => _MapRegionSelectorState();
}

class _MapRegionSelectorState extends State<MapRegionSelector> {
  late final MapController _mapController;
  
  // Selection rectangle corners
  LatLng? _startPoint;
  LatLng? _endPoint;
  
  // Current map bounds
  LatLngBounds? _mapBounds;
  
  // Drag mode for the selection handlers
  _DragMode _dragMode = _DragMode.none;
  
  // Handler positions
  final List<LatLng?> _cornerPositions = List.filled(4, null);
  
  // Maximum area warning
  bool _showMaxAreaWarning = false;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Set initial selection if provided
    if (widget.initialRegion != null) {
      _startPoint = widget.initialRegion!.southWest;
      _endPoint = widget.initialRegion!.northEast;
      
      // Initialize corner positions
      _updateCornerPositions();
      
      // Notify listeners
      _notifyRegionChanged();
    }
  }
  
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: widget.initialCenter,
            zoom: widget.initialZoom,
            minZoom: 3,
            maxZoom: 18,
            interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            onMapReady: _onMapReady,
            onPositionChanged: _onPositionChanged,
            onTap: _onMapTap,
          ),
          children: [
            // Base tile layer
            TileLayer(
              urlTemplate: widget.urlTemplate,
              userAgentPackageName: 'com.bopmaps.app',
            ),
            
            // Selected region
            if (_startPoint != null && _endPoint != null)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: [
                      LatLng(_startPoint!.latitude, _startPoint!.longitude),
                      LatLng(_startPoint!.latitude, _endPoint!.longitude),
                      LatLng(_endPoint!.latitude, _endPoint!.longitude),
                      LatLng(_endPoint!.latitude, _startPoint!.longitude),
                    ],
                    color: Colors.blue.withOpacity(0.2),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),
            
            // Corner handlers
            if (_cornerPositions.every((pos) => pos != null))
              MarkerLayer(
                markers: [
                  // Top-left
                  _buildCornerMarker(_cornerPositions[0]!, _DragMode.topLeft),
                  // Top-right
                  _buildCornerMarker(_cornerPositions[1]!, _DragMode.topRight),
                  // Bottom-right
                  _buildCornerMarker(_cornerPositions[2]!, _DragMode.bottomRight),
                  // Bottom-left
                  _buildCornerMarker(_cornerPositions[3]!, _DragMode.bottomLeft),
                ],
              ),
          ],
        ),
        
        // Selection instructions
        if (_startPoint == null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                color: Colors.white.withOpacity(0.9),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Tap on the map to start selecting a region',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        
        // Maximum area warning
        if (_showMaxAreaWarning)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.amber[100],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The selected area is too large. Maximum allowed area is ${widget.maxAreaSqKm} km².',
                        style: TextStyle(color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Region info panel
        if (_startPoint != null && _endPoint != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Region',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Area: ${_calculateAreaKm2().toStringAsFixed(2)} km²'),
                    const SizedBox(height: 4),
                    Text(
                      'North: ${_getNorth().toStringAsFixed(6)}° | South: ${_getSouth().toStringAsFixed(6)}°',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'East: ${_getEast().toStringAsFixed(6)}° | West: ${_getWest().toStringAsFixed(6)}°',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('CLEAR'),
                          onPressed: _clearSelection,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  /// Builds a corner marker for the selection rectangle
  Marker _buildCornerMarker(LatLng position, _DragMode mode) {
    return Marker(
      point: position,
      width: 24,
      height: 24,
      builder: (context) => GestureDetector(
        onPanStart: (_) => _startDragging(mode),
        onPanUpdate: (details) => _updateDragging(details),
        onPanEnd: (_) => _endDragging(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: const Icon(
            Icons.drag_indicator,
            size: 12,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
  
  /// Handles map ready event
  void _onMapReady() {
    _mapBounds = _mapController.bounds;
    
    // Move to initial region if provided
    if (widget.initialRegion != null) {
      _mapController.fitBounds(
        widget.initialRegion!,
        options: const FitBoundsOptions(padding: EdgeInsets.all(24)),
      );
    }
  }
  
  /// Handles map position changed event
  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (position.bounds != null) {
      _mapBounds = position.bounds;
    }
  }
  
  /// Handles map tap event
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_startPoint == null) {
      // First tap - set start point
      setState(() {
        _startPoint = point;
        _endPoint = point;
        _updateCornerPositions();
      });
    } else if (_startPoint == _endPoint) {
      // Second tap - set end point
      setState(() {
        _endPoint = point;
        _updateCornerPositions();
        _checkMaxArea();
        _notifyRegionChanged();
      });
    } else {
      // Reset and start new selection
      setState(() {
        _startPoint = point;
        _endPoint = point;
        _updateCornerPositions();
        _showMaxAreaWarning = false;
      });
    }
  }
  
  /// Start dragging a corner
  void _startDragging(_DragMode mode) {
    _dragMode = mode;
  }
  
  /// Update dragging position
  void _updateDragging(DragUpdateDetails details) {
    if (_dragMode == _DragMode.none || _mapBounds == null) return;
    
    // Convert screen position to LatLng
    final screenPoint = details.globalPosition;
    final renderBox = context.findRenderObject() as RenderBox;
    final localPoint = renderBox.globalToLocal(screenPoint);
    
    // Get the map's dimensions
    final mapSize = Size(renderBox.size.width, renderBox.size.height);
    
    // Calculate the new point on the map
    final newPoint = _mapController.pointToLatLng(CustomPoint(
      localPoint.dx,
      localPoint.dy,
    ));
    
    if (newPoint == null) return;
    
    // Update the appropriate corner based on drag mode
    setState(() {
      switch (_dragMode) {
        case _DragMode.topLeft:
          _startPoint = LatLng(newPoint.latitude, newPoint.longitude);
          break;
        case _DragMode.topRight:
          _startPoint = LatLng(newPoint.latitude, _startPoint!.longitude);
          _endPoint = LatLng(_endPoint!.latitude, newPoint.longitude);
          break;
        case _DragMode.bottomRight:
          _endPoint = LatLng(newPoint.latitude, newPoint.longitude);
          break;
        case _DragMode.bottomLeft:
          _endPoint = LatLng(newPoint.latitude, _endPoint!.longitude);
          _startPoint = LatLng(_startPoint!.latitude, newPoint.longitude);
          break;
        case _DragMode.none:
          break;
      }
      
      _updateCornerPositions();
      _checkMaxArea();
      _notifyRegionChanged();
    });
  }
  
  /// End dragging
  void _endDragging() {
    _dragMode = _DragMode.none;
  }
  
  /// Update the corner positions based on start and end points
  void _updateCornerPositions() {
    if (_startPoint == null || _endPoint == null) return;
    
    final north = _getNorth();
    final south = _getSouth();
    final east = _getEast();
    final west = _getWest();
    
    _cornerPositions[0] = LatLng(north, west); // Top-left
    _cornerPositions[1] = LatLng(north, east); // Top-right
    _cornerPositions[2] = LatLng(south, east); // Bottom-right
    _cornerPositions[3] = LatLng(south, west); // Bottom-left
  }
  
  /// Clear the current selection
  void _clearSelection() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _cornerPositions.fillRange(0, 4, null);
      _showMaxAreaWarning = false;
    });
    
    // Notify listeners
    if (widget.onRegionChanged != null) {
      widget.onRegionChanged!(LatLngBounds(
        LatLng(0, 0),
        LatLng(0, 0),
      ));
    }
  }
  
  /// Check if the selected area exceeds the maximum allowed area
  void _checkMaxArea() {
    final areaKm2 = _calculateAreaKm2();
    _showMaxAreaWarning = areaKm2 > widget.maxAreaSqKm;
  }
  
  /// Calculate the area in square kilometers
  double _calculateAreaKm2() {
    if (_startPoint == null || _endPoint == null) return 0;
    
    return MapSizeCalculator.calculateAreaKm2(
      _getNorth(),
      _getSouth(),
      _getEast(),
      _getWest(),
    );
  }
  
  /// Get the north coordinate of the selection
  double _getNorth() {
    if (_startPoint == null || _endPoint == null) return 0;
    return math.max(_startPoint!.latitude, _endPoint!.latitude);
  }
  
  /// Get the south coordinate of the selection
  double _getSouth() {
    if (_startPoint == null || _endPoint == null) return 0;
    return math.min(_startPoint!.latitude, _endPoint!.latitude);
  }
  
  /// Get the east coordinate of the selection
  double _getEast() {
    if (_startPoint == null || _endPoint == null) return 0;
    return math.max(_startPoint!.longitude, _endPoint!.longitude);
  }
  
  /// Get the west coordinate of the selection
  double _getWest() {
    if (_startPoint == null || _endPoint == null) return 0;
    return math.min(_startPoint!.longitude, _endPoint!.longitude);
  }
  
  /// Notify listeners of region changes
  void _notifyRegionChanged() {
    if (widget.onRegionChanged != null && _startPoint != null && _endPoint != null) {
      widget.onRegionChanged!(LatLngBounds(
        LatLng(_getSouth(), _getWest()),
        LatLng(_getNorth(), _getEast()),
      ));
    }
  }
}

/// Enumeration of drag modes for the corner handlers
enum _DragMode {
  none,
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
} 