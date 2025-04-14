import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import 'map_cache_manager.dart';

class OfflineIndicatorWidget extends StatefulWidget {
  final LatLng? currentCenter;
  final double currentZoom;
  final bool isOnline;
  final VoidCallback? onManageOfflineMaps;

  const OfflineIndicatorWidget({
    Key? key,
    required this.currentCenter,
    required this.currentZoom,
    required this.isOnline,
    this.onManageOfflineMaps,
  }) : super(key: key);

  @override
  State<OfflineIndicatorWidget> createState() => _OfflineIndicatorWidgetState();
}

class _OfflineIndicatorWidgetState extends State<OfflineIndicatorWidget> with SingleTickerProviderStateMixin {
  final MapCacheManager _cacheManager = MapCacheManager();
  
  bool _isInOfflineRegion = false;
  String? _currentRegionName;
  bool _isCheckingRegion = false;
  Timer? _debounceTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
    
    _animationController.repeat(reverse: true);
    
    // Initial check
    _checkIfInOfflineRegion();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OfflineIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if we need to update the offline region status
    if (widget.currentCenter != oldWidget.currentCenter || 
        widget.currentZoom != oldWidget.currentZoom) {
      // Debounce to avoid too many checks
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkIfInOfflineRegion();
      });
    }
    
    // Update animation state based on online status
    if (!widget.isOnline && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (widget.isOnline && _animationController.isAnimating && !_isInOfflineRegion) {
      _animationController.stop();
      _animationController.value = 1.0;
    }
  }
  
  Future<void> _checkIfInOfflineRegion() async {
    if (widget.currentCenter == null || _isCheckingRegion) return;
    
    setState(() {
      _isCheckingRegion = true;
    });
    
    try {
      final result = await _cacheManager.isLocationInDownloadedRegion(
        widget.currentCenter!,
        widget.currentZoom.round(),
      );
      
      setState(() {
        _isInOfflineRegion = result['isInRegion'] as bool;
        _currentRegionName = result['regionName'] as String?;
        _isCheckingRegion = false;
      });
      
      // If we're in an offline region but not online, make sure animation is running
      if (_isInOfflineRegion && !widget.isOnline && !_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      } else if (!_isInOfflineRegion && !widget.isOnline && !_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      } else if (widget.isOnline && !_isInOfflineRegion && _animationController.isAnimating) {
        _animationController.stop();
        _animationController.value = 1.0;
      }
    } catch (e) {
      debugPrint('Error checking offline region: $e');
      setState(() {
        _isCheckingRegion = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // If online and not in offline region, don't show anything
    if (widget.isOnline && !_isInOfflineRegion) {
      return const SizedBox.shrink();
    }
    
    // Determine what to display
    String displayText;
    Color backgroundColor;
    IconData icon;
    
    if (!widget.isOnline && _isInOfflineRegion) {
      // Offline but using offline data
      displayText = 'Offline • Using $_currentRegionName';
      backgroundColor = Colors.amber.shade700;
      icon = Icons.offline_bolt;
    } else if (!widget.isOnline) {
      // Completely offline with no data
      displayText = 'No internet connection';
      backgroundColor = Colors.red.shade700;
      icon = Icons.wifi_off;
    } else if (_isInOfflineRegion) {
      // Online but using cached data
      displayText = 'Using offline map: $_currentRegionName';
      backgroundColor = Colors.blue.shade700;
      icon = Icons.map;
    } else {
      // Should never reach here, but just in case
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: SafeArea(
        child: FadeTransition(
          opacity: _animation,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onManageOfflineMaps,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OfflineAreaOverlay extends StatelessWidget {
  final List<dynamic> downloadedRegions;
  final double opacity;
  
  const OfflineAreaOverlay({
    Key? key,
    required this.downloadedRegions,
    this.opacity = 0.2,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (downloadedRegions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return CustomPaint(
      size: Size.infinite,
      painter: OfflineAreaPainter(
        regions: downloadedRegions,
        opacity: opacity,
      ),
    );
  }
}

class OfflineAreaPainter extends CustomPainter {
  final List<dynamic> regions;
  final double opacity;
  
  OfflineAreaPainter({
    required this.regions,
    required this.opacity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue.withOpacity(opacity)
      ..style = PaintingStyle.fill;
      
    for (final region in regions) {
      // Draw the region bounds
      // In a real implementation, this would convert lat/lng to screen coordinates
      // For demo purposes, we'll use simplified rectangles
      
      // Example:
      // final bounds = region['bounds'];
      // final rect = Rect.fromLTRB(bounds.west, bounds.north, bounds.east, bounds.south);
      // canvas.drawRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(OfflineAreaPainter oldDelegate) {
    return oldDelegate.regions != regions || oldDelegate.opacity != opacity;
  }
} 