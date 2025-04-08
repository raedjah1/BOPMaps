import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class MapControlsWidget extends StatefulWidget {
  final VoidCallback onLocationButtonTap;
  
  const MapControlsWidget({
    Key? key,
    required this.onLocationButtonTap,
  }) : super(key: key);
  
  @override
  State<MapControlsWidget> createState() => _MapControlsWidgetState();
}

class _MapControlsWidgetState extends State<MapControlsWidget> {
  bool _isLoadingLocation = false;
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location button with loading state
          FloatingActionButton(
            heroTag: 'location',
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            onPressed: _isLoadingLocation ? null : _handleLocationButtonTap,
            child: _isLoadingLocation
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
  
  // Handle location button tap with loading state
  Future<void> _handleLocationButtonTap() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permission permanently denied');
        return;
      }
      
      // Execute callback
      widget.onLocationButtonTap();
    } catch (e) {
      _showErrorSnackBar('Error getting location: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }
  
  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 