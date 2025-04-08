import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

import '../../config/constants.dart';
import '../../providers/map_provider.dart';
import 'map_pin_widget.dart';
import 'map_layers/terrain_layer.dart';
import 'map_layers/buildings_layer.dart';

class FlutterMapWidget extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(Map<String, dynamic>) onPinTap;

  const FlutterMapWidget({
    Key? key,
    required this.mapProvider,
    required this.onPinTap,
  }) : super(key: key);

  @override
  State<FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<FlutterMapWidget> {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  
  @override
  Widget build(BuildContext context) {
    // Create markers from pins
    final markers = _createMarkers();
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          AppConstants.defaultLatitude,
          AppConstants.defaultLongitude
        ),
        initialZoom: AppConstants.defaultZoom,
        minZoom: AppConstants.minZoom,
        maxZoom: AppConstants.maxZoom,
        onMapEvent: _handleMapEvent,
      ),
      children: [
        // Base tile layer (modern styled map)
        TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
          additionalOptions: {
            'accessToken': AppConstants.mapboxAccessToken,
          },
          backgroundColor: const Color(0xFF121212),
        ),
        
        // Custom terrain layer (can be optimized by level of detail)
        const TerrainLayer(),
        
        // Custom buildings layer (can be optimized by level of detail)
        const BuildingsLayer(),
        
        // Markers cluster layer for pins
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            fitBoundsOptions: const FitBoundsOptions(
              padding: EdgeInsets.all(50),
            ),
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
    );
  }
  
  void _handleMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      // Update map provider with new viewport
      widget.mapProvider.updateViewport(
        latitude: event.center.latitude,
        longitude: event.center.longitude,
        zoom: event.zoom,
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
  
  // Build cluster widget
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          markers.length.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  // Build popup for a pin
  Widget _buildPinPopup(Map<String, dynamic> pinData) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
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
                TextButton(
                  onPressed: () => widget.onPinTap(pinData),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
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
    required WidgetBuilder builder,
    double width = 30.0,
    double height = 30.0,
    Alignment? alignment,
  }) : super(
         point: point,
         builder: builder,
         width: width,
         height: height,
         alignment: alignment ?? Alignment.topCenter,
       );
} 