import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// This widget is deprecated - use controls from the controls/ directory instead
/// Kept for backward compatibility but will not display any UI elements
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
    // Return empty widget - controls have been moved to separate components
    return const SizedBox.shrink();
    
    // Original implementation commented out
    /*
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
    */
  }
  
  // Handle location button tap with loading state
  Future<void> _handleLocationButtonTap() async {
    // Implementation preserved for backward compatibility
    // but will never be called due to empty build method
    
    widget.onLocationButtonTap();
  }
  
  // Show error snackbar
  void _showErrorSnackBar(String message) {
    // Implementation preserved for backward compatibility
    // but will never be called due to empty build method
  }
} 