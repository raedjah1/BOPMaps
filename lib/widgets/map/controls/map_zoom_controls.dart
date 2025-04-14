import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../optimized_map_controller.dart';
import '../../../config/map_styles.dart';
import 'map_control_button.dart';

/// Widget that provides zoom in/out and tilt controls for the map
class MapZoomControls extends StatelessWidget {
  final OptimizedMapController mapController;
  final LatLng currentCenter;
  final double currentZoom;
  final VoidCallback toggleTilt;
  final bool isLocationTracking;
  final Position? currentPosition;
  final VoidCallback toggleLocationTracking;
  final VoidCallback downloadCurrentArea;
  final VoidCallback toggleZoomLevelNavigator;
  final bool showZoomLevelNavigator;

  const MapZoomControls({
    Key? key,
    required this.mapController,
    required this.currentCenter,
    required this.currentZoom,
    required this.toggleTilt,
    required this.isLocationTracking,
    required this.currentPosition,
    required this.toggleLocationTracking,
    required this.downloadCurrentArea,
    required this.toggleZoomLevelNavigator,
    this.showZoomLevelNavigator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 85,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tilt control
          MapControlButton(
            icon: Icons.layers,
            tooltip: '3D Toggle',
            onPressed: toggleTilt,
          ),
          const SizedBox(height: 8),
          
          // Zoom level navigator toggle
          MapControlButton(
            icon: Icons.swap_vert,
            tooltip: showZoomLevelNavigator ? 'Hide Zoom Levels' : 'Show Zoom Levels',
            onPressed: toggleZoomLevelNavigator,
            backgroundColor: showZoomLevelNavigator 
                ? Colors.blue.shade100 
                : Colors.white,
            iconColor: showZoomLevelNavigator 
                ? Colors.blue.shade800 
                : Colors.black54,
          ),
          const SizedBox(height: 8),
          
          // Zoom in
          MapControlButton(
            icon: Icons.add,
            tooltip: 'Zoom In',
            onPressed: () => mapController.animateTo(
              location: currentCenter,
              zoom: currentZoom + 1,
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          
          // Zoom out
          MapControlButton(
            icon: Icons.remove,
            tooltip: 'Zoom Out',
            onPressed: () => mapController.animateTo(
              location: currentCenter,
              zoom: currentZoom - 1,
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          
          // Toggle location tracking
          MapControlButton(
            icon: isLocationTracking
              ? Icons.my_location
              : Icons.location_searching,
            tooltip: isLocationTracking
              ? 'Tracking On'
              : 'Locate Me',
            onPressed: () {
              if (currentPosition != null) {
                toggleLocationTracking();
                mapController.animateTo(
                  location: LatLng(
                    currentPosition!.latitude,
                    currentPosition!.longitude,
                  ),
                  zoom: 16,
                  duration: const Duration(milliseconds: 500),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          
          // Download current area
          MapControlButton(
            icon: Icons.download,
            tooltip: 'Save For Offline',
            onPressed: downloadCurrentArea,
          ),
        ],
      ),
    );
  }
} 