import 'package:flutter/material.dart';
import '../../../providers/map_provider.dart';

/// Widget that provides location and compass navigation controls
class MapNavigationControls extends StatelessWidget {
  final MapProvider mapProvider;
  final bool useLeafletMap;
  final Function(double latitude, double longitude, {double? zoom}) animateToLocation;
  final VoidCallback resetMapView;
  final bool isVisible;

  const MapNavigationControls({
    Key? key,
    required this.mapProvider,
    required this.useLeafletMap,
    required this.animateToLocation,
    required this.resetMapView,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: isVisible ? 90 : -60,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'current_location',
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.my_location),
            onPressed: () {
              // Center map on current location with animation
              if (mapProvider.currentPosition != null) {
                animateToLocation(
                  mapProvider.currentPosition!.latitude,
                  mapProvider.currentPosition!.longitude,
                  zoom: 16.0,
                );
                
                // Turn on location tracking
                if (!mapProvider.isLocationTracking) {
                  mapProvider.toggleLocationTracking();
                }
              }
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'compass',
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.compass_calibration),
            onPressed: resetMapView,
          ),
        ],
      ),
    );
  }
} 