import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../widgets/map/flutter_map_widget.dart';
import '../widgets/map/leaflet_map_widget.dart';
import '../widgets/navigation/top_navigation_bar.dart';
import '../widgets/navigation/bottom_navigation_bar.dart';
import '../config/constants.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  
  const MapScreen({Key? key}) : super(key: key);
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapProvider _mapProvider;
  bool _useLeafletMap = false; // Default to Flutter map implementation
  bool _showZoomControls = true;
  bool _showCompass = true;
  int _currentNavIndex = 0; // Current bottom nav index
  
  // Animation controller for pin drop effect
  late AnimationController _dropAnimationController;
  
  // Use a GlobalKey with the correct state type
  final GlobalKey<FlutterMapWidgetState> _mapKey = GlobalKey<FlutterMapWidgetState>();

  @override
  void initState() {
    super.initState();
    _mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    // Initialize pin drop animation controller
    _dropAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Request user location permissions
    _requestLocationPermission();
    
    // Hide controls after a delay
    _startHideControlsTimer();
  }
  
  @override
  void dispose() {
    _dropAnimationController.dispose();
    super.dispose();
  }
  
  // Request location permission on startup
  Future<void> _requestLocationPermission() async {
    await _mapProvider.requestLocationPermission();
  }
  
  // Handle UI visibility timer
  Timer? _controlsTimer;
  
  void _startHideControlsTimer() {
    _controlsTimer?.cancel();
    
    _controlsTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showZoomControls = false;
          _showCompass = false;
        });
      }
    });
  }
  
  void _showControls() {
    if (!_showZoomControls || !_showCompass) {
      setState(() {
        _showZoomControls = true;
        _showCompass = true;
      });
      _startHideControlsTimer();
    }
  }
  
  // Handle pin tap
  void _handlePinTap(Map<String, dynamic> pinData) {
    // First reset controls timer to keep UI visible during interaction
    _showControls();
    
    // Then show pin details
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPinDetailsSheet(pinData),
    );
  }
  
  // Show dialog to add a new pin
  void _showAddPinDialog() {
    // First reset controls timer
    _showControls();
    
    // Then show animation and dialog
    _dropAnimationController.forward(from: 0.0).then((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Drop Music Pin'),
          content: const Text('Would you like to drop a music pin at your current location?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Add logic to actually drop a pin
              },
              child: const Text('Drop It'),
            ),
          ],
        ),
      );
    });
  }
  
  // Handle bottom navigation selection
  void _handleNavigation(int index) {
    setState(() {
      _currentNavIndex = index;
    });
    
    // Improved navigation logic with different actions per section
    switch (index) {
      case 0: // Explore - already on this screen
        // Already on map/explore screen, reset view
        if (_mapKey.currentState != null) {
          _mapKey.currentState!.resetMapView();
        }
        break;
      case 1: // Collection - show music collection
        // For now just show a snackbar since we don't have the screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Music Collection - Coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 2: // Friends
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friends - Coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 3: // Profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile - Coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }
  
  // Build the bottom sheet for pin details
  Widget _buildPinDetailsSheet(Map<String, dynamic> pinData) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 16),
            ),
          ),
          Text(
            pinData['title'] ?? 'Unknown Track',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pinData['artist'] ?? 'Unknown Artist',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  pinData['rarity'] ?? 'Common',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Dropped ${pinData['timestamp'] ?? 'recently'}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Add logic to collect/play the pin
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Collect This Track'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: _showControls,
      onPanDown: (_) => _showControls(),
      child: Scaffold(
        appBar: TopNavigationBar(
          title: 'BOP Maps',
          onSearchTap: () {
            // Handle search action - shows music search screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Music Search - Coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          onSettingsTap: () {
            // Show map settings sheet
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => _buildMapSettingsSheet(context),
            );
          },
          actions: [
            // Map type selector
            PopupMenuButton<String>(
              icon: const Icon(Icons.layers),
              onSelected: (value) {
                setState(() {
                  if (value == 'leaflet') {
                    _useLeafletMap = true;
                  } else {
                    _useLeafletMap = false;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'flutter',
                  child: Text('Flutter Map'),
                ),
                const PopupMenuItem(
                  value: 'leaflet',
                  child: Text('Leaflet JS Map'),
                ),
              ],
            ),
          ],
        ),
        body: _buildMapBody(),
        bottomNavigationBar: MusicPinBottomNavBar(
          currentIndex: _currentNavIndex,
          onTabSelected: _handleNavigation,
          onAddPinPressed: _showAddPinDialog,
        ),
      ),
    );
  }
  
  // Map body with all layers and controls
  Widget _buildMapBody() {
    return Stack(
      children: [
        // Map widget
        _useLeafletMap
            ? LeafletMapWidget(
                mapProvider: _mapProvider,
                onPinTap: _handlePinTap,
              )
            : FlutterMapWidget(
                key: _mapKey,
                mapProvider: _mapProvider,
                onPinTap: _handlePinTap,
              ),
                
        // Pin drop animation overlay
        AnimatedBuilder(
          animation: _dropAnimationController,
          builder: (context, child) {
            if (_dropAnimationController.value == 0) {
              return const SizedBox.shrink();
            }
            
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PinDropPainter(
                    animation: _dropAnimationController,
                    color: Theme.of(context).primaryColor,
                  ),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),
        
        // Current location button and compass with animation
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showZoomControls ? 90 : -60,
          right: 16,
          child: _buildMapControls(),
        ),
        
        // Dynamic status messages (discoveries, etc)
        _buildStatusMessages(),
      ],
    );
  }
  
  // Map controls (location, compass, etc)
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'current_location',
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.my_location),
          onPressed: () {
            // Center map on current location with animation
            if (_mapProvider.currentPosition != null) {
              if (!_useLeafletMap && _mapKey.currentState != null) {
                _mapKey.currentState!.animateToLocation(
                  _mapProvider.currentPosition!.latitude,
                  _mapProvider.currentPosition!.longitude,
                  zoom: 16.0,
                );
              } else {
                _mapProvider.updateViewport(
                  latitude: _mapProvider.currentPosition!.latitude,
                  longitude: _mapProvider.currentPosition!.longitude,
                  zoom: 16.0,
                );
              }
              
              // Turn on location tracking
              if (!_mapProvider.isLocationTracking) {
                _mapProvider.toggleLocationTracking();
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
          onPressed: () {
            // Reset map rotation and tilt
            if (!_useLeafletMap && _mapKey.currentState != null) {
              _mapKey.currentState!.resetMapView();
            }
          },
        ),
      ],
    );
  }
  
  // Status messages for errors, notifications
  Widget _buildStatusMessages() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        if (mapProvider.hasNetworkError) {
          return Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mapProvider.errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  
  // Bottom sheet for map settings
  Widget _buildMapSettingsSheet(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 16),
            ),
          ),
          Text(
            'Map Settings',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          
          // Map Layer toggles
          Text(
            'Map Style',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildSettingsOption(
            context,
            title: 'Standard View',
            subtitle: 'Flat map view',
            icon: Icons.map_outlined,
            value: !(_useLeafletMap || _mapKey.currentState?.tiltAnimation.value != 0),
            onChanged: (value) {
              if (value && _mapKey.currentState != null) {
                setState(() {
                  _useLeafletMap = false;
                });
                _mapKey.currentState!.resetMapView();
              }
              Navigator.pop(context);
            },
          ),
          const Divider(),
          _buildSettingsOption(
            context,
            title: '2.5D View',
            subtitle: 'Perspective with buildings',
            icon: Icons.view_in_ar_outlined,
            value: !_useLeafletMap && _mapKey.currentState?.tiltAnimation.value != 0,
            onChanged: (value) {
              if (value && _mapKey.currentState != null) {
                setState(() {
                  _useLeafletMap = false;
                });
                if (_mapKey.currentState!.tiltAnimation.value == 0) {
                  _mapKey.currentState!.toggleTilt();
                }
              }
              Navigator.pop(context);
            },
          ),
          const Divider(),
          _buildSettingsOption(
            context,
            title: 'Leaflet Map',
            subtitle: 'Alternative map engine',
            icon: Icons.public,
            value: _useLeafletMap,
            onChanged: (value) {
              setState(() {
                _useLeafletMap = value;
              });
              Navigator.pop(context);
            },
          ),
          
          // Other settings as needed
          const SizedBox(height: 24),
          Text(
            'Display Options',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Show Buildings'),
            subtitle: const Text('3D buildings on the map'),
            value: true, // TODO: Connect to actual settings
            onChanged: (value) {
              // TODO: Implement building toggle
            },
          ),
          SwitchListTile(
            title: const Text('Music Pin Clustering'),
            subtitle: const Text('Group nearby pins on the map'),
            value: true, // TODO: Connect to actual settings
            onChanged: (value) {
              // TODO: Implement clustering toggle
            },
          ),
        ],
      ),
    );
  }
  
  // Helper to build settings options
  Widget _buildSettingsOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => onChanged(true),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: value ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.subtitle1?.copyWith(
                      fontWeight: value ? FontWeight.bold : FontWeight.normal,
                      color: value ? theme.colorScheme.primary : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.caption,
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: value,
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the pin drop animation
class PinDropPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  
  PinDropPainter({
    required this.animation,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate center of screen
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw ripple effect
    final ripplePaint = Paint()
      ..color = color.withOpacity(0.3 * (1 - animation.value))
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(
      center,
      50 + (animation.value * 100),
      ripplePaint,
    );
    
    // Draw pin that drops from top
    final pinY = size.height * 0.3 * (1 - animation.value);
    
    // Pin head
    final pinHeadPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(
      Offset(center.dx, center.dy - 15 + pinY),
      15,
      pinHeadPaint,
    );
    
    // Pin shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2 * animation.value)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 30),
        width: 20 * animation.value,
        height: 10 * animation.value,
      ),
      shadowPaint,
    );
    
    // Pin tail
    final pinPath = Path()
      ..moveTo(center.dx, center.dy - 15 + pinY)
      ..lineTo(center.dx - 10, center.dy + pinY)
      ..lineTo(center.dx + 10, center.dy + pinY)
      ..close();
      
    canvas.drawPath(pinPath, pinHeadPaint);
  }
  
  @override
  bool shouldRepaint(covariant PinDropPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value;
  }
} 