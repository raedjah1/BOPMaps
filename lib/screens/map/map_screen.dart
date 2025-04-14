import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Temporarily commenting out mapbox import
// import 'package:mapbox_gl/mapbox_gl.dart';
import '../../config/constants.dart';
import '../../config/themes.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
// import '../../widgets/map/aura_effect_widget.dart';
// import '../../widgets/map/pin_widget.dart';
import '../../widgets/music/track_preview_modal.dart';
import '../music/track_select_screen.dart';
import '../../widgets/common/network_error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
// import '../../widgets/map/shimmer_pin_widget.dart';
import '../../widgets/bottomsheets/create_pin_bottomsheet.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../widgets/map/flutter_map_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controller for the bottom sheet
  final PersistentBottomSheetController? _bottomSheetController = null;
  
  @override
  void initState() {
    super.initState();
    
    // Force refresh map data on init and request location first
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      
      // First request location permission and get location
      try {
        await mapProvider.requestLocationPermission();
        debugPrint('Location permission requested in MapScreen');
      } catch (e) {
        debugPrint('Error requesting location permission: $e');
      }
      
      // Then refresh pins
      mapProvider.refreshPins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, AuthProvider>(
      builder: (context, mapProvider, authProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("BOPMaps", style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main map widget (modular component)
              FlutterMapWidget(
                mapProvider: mapProvider,
                onPinTap: _showPinDetails,
              ),
              
              // Loading indicator 
              if (mapProvider.isLoading)
                const Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
          
          // Bottom navigation
          bottomNavigationBar: _buildBottomNavBar(context),
          
          // Floating action button for dropping pins
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreatePinBottomSheet,
            child: const Icon(Icons.add_location),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }
  
  // Placeholder for methods that use Mapbox
  
  // Build pins layer
  Widget _buildPinsLayer(MapProvider mapProvider) {
    return const SizedBox.shrink();
  }
  
  // Build bottom navigation bar
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Map',
            onPressed: () {
              // Already on map screen
            },
          ),
          const SizedBox(width: 48), // Space for FAB
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Library',
            onPressed: () {
              Navigator.pushNamed(context, '/library');
            },
          ),
        ],
      ),
    );
  }
  
  // Show pin details
  void _showPinDetails(Map<String, dynamic> pin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPinDetailsModal(pin),
    );
  }
  
  // Build pin details modal
  Widget _buildPinDetailsModal(Map<String, dynamic> pin) {
    // Placeholder implementation
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pin['title'] ?? 'Unknown Track',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            pin['artist'] ?? 'Unknown Artist',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Collect'),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collection feature coming soon')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Show create pin bottom sheet
  void _showCreatePinBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => CreatePinBottomsheet(
        onCreateRegular: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/track_select', arguments: {
            'pinType': 'regular',
          });
        },
        onCreateCustom: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/track_select', arguments: {
            'pinType': 'custom',
          });
        },
        onCreatePlaylist: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/track_select', arguments: {
            'pinType': 'playlist',
          });
        },
        onClose: () {
          Navigator.pop(context);
        },
      ),
    );
  }
  
  // Stub for what's playing nearby button
  Widget _buildWhatsPlayingNearbyButton(BuildContext context, MapProvider mapProvider) {
    return const SizedBox.shrink();
  }
} 