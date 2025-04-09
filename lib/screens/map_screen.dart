import 'package:flutter/material.dart';
import '../providers/map_provider.dart';
import '../widgets/map/flutter_map_widget.dart';
import '../widgets/map/leaflet_map_widget.dart';
import '../config/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late MapProvider _mapProvider;
  bool _useLeafletMap = true;
  bool _showZoomControls = true;
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  
  // Animation controller for the pin drop
  late AnimationController _dropAnimationController;
  
  @override
  void initState() {
    super.initState();
    _mapProvider = MapProvider();
    _loadPins();
    
    // Initialize animation controller
    _dropAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _dropAnimationController.dispose();
    super.dispose();
  }
  
  void _loadPins() {
    // Load the pins from your data source
    _mapProvider.refreshPins();
  }
  
  void _handlePinTap(Map<String, dynamic> pinData) {
    // Handle when a pin is tapped
    print('Pin tapped: ${pinData['title']}');
    
    // Show pin details in a bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildPinDetails(pinData),
    );
  }
  
  Widget _buildPinDetails(Map<String, dynamic> pin) {
    final Color pinColor = _getPinColorByRarity(pin['rarity'] ?? 'Common');
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: pinColor.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 40,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pinColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pin['rarity'] ?? 'Common',
                        style: TextStyle(
                          color: pinColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (pin['is_collected'] == true)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  pin['title'] ?? 'Untitled Track',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pin['artist'] ?? 'Unknown Artist',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                // Play button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Track'),
                  onPressed: () {
                    // TODO: Implement music playback
                    Navigator.pop(context);
                  },
                ),
                
                // Show a more button for additional actions
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('More Options'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade400,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showPinOptionsMenu(pin);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showPinOptionsMenu(Map<String, dynamic> pin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share Pin', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement sharing functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share functionality coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions, color: Colors.white),
              title: const Text('Get Directions', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement directions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Directions functionality coming soon!')),
                );
              },
            ),
            if (pin['is_collected'] != true)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.white),
                title: const Text('Mark as Collected', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement collection marking
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pin marked as collected!')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getPinColorByRarity(String rarity) {
    switch (rarity) {
      case 'Common':
        return Colors.grey;
      case 'Uncommon':
        return Colors.green;
      case 'Rare':
        return Colors.blue;
      case 'Epic':
        return Colors.purple;
      case 'Legendary':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  void _showAddPinDialog() {
    // Reset the controllers
    _titleController.clear();
    _artistController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Drop a Music Pin',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Track Title',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _artistController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Artist',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Drop Pin'),
            onPressed: () {
              _dropPin();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _dropPin() async {
    // Make sure we have a current position
    if (_mapProvider.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Start the drop animation
    _dropAnimationController.reset();
    _dropAnimationController.forward();

    // Generate a random rarity for the pin
    final rarity = _mapProvider.determinePinRarity();

    // Add the pin
    final newPin = await _mapProvider.addPin(
      latitude: _mapProvider.currentPosition!.latitude,
      longitude: _mapProvider.currentPosition!.longitude,
      title: _titleController.text.isNotEmpty ? _titleController.text : 'Untitled Track',
      artist: _artistController.text.isNotEmpty ? _artistController.text : 'Unknown Artist',
      trackUrl: 'https://example.com/tracks/sample.mp3', // Replace with real logic
      rarity: rarity,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 8),
            Text('Dropped a $rarity music pin!'),
          ],
        ),
        backgroundColor: _getPinColorByRarity(rarity),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            if (newPin != null) {
              _handlePinTap(newPin);
            }
          },
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text('BOP Maps');
          },
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        actions: [
          // Map type toggle
          IconButton(
            icon: Icon(_useLeafletMap ? Icons.map : Icons.public),
            tooltip: _useLeafletMap ? "Switch to Flutter Map" : "Switch to Leaflet Map",
            onPressed: () {
              setState(() {
                _useLeafletMap = !_useLeafletMap;
              });
            },
          ),
          // Show/hide zoom controls
          IconButton(
            icon: Icon(_showZoomControls ? Icons.zoom_in_map : Icons.zoom_out_map),
            tooltip: _showZoomControls ? "Hide Zoom Controls" : "Show Zoom Controls",
            onPressed: () {
              setState(() {
                _showZoomControls = !_showZoomControls;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map widget
          _useLeafletMap
              ? LeafletMapWidget(
                  mapProvider: _mapProvider,
                  onPinTap: _handlePinTap,
                )
              : FlutterMapWidget(
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
          
          // Current location button and compass
          if (_showZoomControls)
            Positioned(
              bottom: 90,
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
                      // Center map on current location
                      if (_mapProvider.currentPosition != null) {
                        _mapProvider.updateViewport(
                          latitude: _mapProvider.currentPosition!.latitude,
                          longitude: _mapProvider.currentPosition!.longitude,
                          zoom: AppConstants.defaultZoom,
                        );
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
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPinDialog,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Drop Music Pin'),
      ),
    );
  }
}

// Custom painter for the pin drop animation
class PinDropPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  
  PinDropPainter({required this.animation, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Only show animation for first half of the animation
    if (animation.value > 0.5) return;
    
    // Adjusted animation value to make it look good in the first half
    final animValue = animation.value * 2;
    
    // Draw a ripple effect
    final paint = Paint()
      ..color = color.withOpacity(0.3 * (1 - animValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.3;
    final radius = maxRadius * animValue;
    
    canvas.drawCircle(center, radius, paint);
    
    // Draw a second outer ripple
    final paint2 = Paint()
      ..color = color.withOpacity(0.2 * (1 - animValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius * 1.3, paint2);
  }
  
  @override
  bool shouldRepaint(covariant PinDropPainter oldDelegate) {
    return animation != oldDelegate.animation || color != oldDelegate.color;
  }
} 