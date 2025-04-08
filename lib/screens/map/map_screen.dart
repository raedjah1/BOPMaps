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
    // Force refresh map data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      // Temporarily disable refreshing pins until mapbox is setup
      // mapProvider.refreshPins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, AuthProvider>(
      builder: (context, mapProvider, authProvider, child) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map, size: 100, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  "Map Temporarily Unavailable",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "The Mapbox dependency is temporarily disabled to allow the app to run. Please re-enable mapbox_gl in pubspec.yaml to use the full map functionality.",
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please re-enable the Mapbox dependency to use this feature"),
                      ),
                    );
                  },
                  child: const Text("Simulate Refresh"),
                ),
              ],
            ),
          ),
          
          // Bottom navigation
          bottomNavigationBar: _buildBottomNavBar(context),
          
          // Floating action button for dropping pins
          floatingActionButton: _buildFloatingActionButton(context, mapProvider),
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
  
  // Build floating action button
  Widget _buildFloatingActionButton(BuildContext context, MapProvider mapProvider) {
    return FloatingActionButton(
      onPressed: () {
        // Show pin creation bottom sheet
        _showCreatePinBottomSheet(context, mapProvider);
      },
      child: const Icon(Icons.add_location),
    );
  }
  
  // Show create pin bottom sheet
  void _showCreatePinBottomSheet(BuildContext context, MapProvider mapProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CreatePinBottomsheet(
        onCreateRegular: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Map functionality is temporarily disabled - Single Track Pin"),
            ),
          );
        },
        onCreateCustom: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Map functionality is temporarily disabled - Custom Music Pin"),
            ),
          );
        },
        onCreatePlaylist: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Map functionality is temporarily disabled - Playlist Pin"),
            ),
          );
        },
        onClose: () {
          Navigator.pop(context);
        },
      ),
    );
  }
  
  // Show pin details (stubbed)
  void _showPinDetails(BuildContext context, Map<String, dynamic> pin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TrackPreviewModal(
        pin: pin,
        isCollected: false,
        onCollect: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
              content: Text("Collection functionality is temporarily disabled"),
                  ),
                );
              },
        onShare: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sharing functionality is temporarily disabled"),
            ),
          );
        },
      ),
    );
  }
  
  // Stub for what's playing nearby button
  Widget _buildWhatsPlayingNearbyButton(BuildContext context, MapProvider mapProvider) {
    return const SizedBox.shrink();
  }
} 