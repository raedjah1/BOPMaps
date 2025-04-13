import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A widget that displays the user's location on the map with a pulsing animation
/// and directional indicator, similar to Uber's user location marker
class UserLocationMarker extends StatefulWidget {
  final LatLng position;
  final double? heading;
  final Color primaryColor;
  final Color? pulseColor;

  const UserLocationMarker({
    Key? key,
    required this.position,
    this.heading,
    required this.primaryColor,
    this.pulseColor,
  }) : super(key: key);

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Create a repeating pulse animation
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _pulseAnimationController.repeat();
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pulseColor = widget.pulseColor ?? widget.primaryColor.withOpacity(0.4);
    
    return MarkerLayer(
      markers: [
        Marker(
          width: 100.0, // Make the marker wider to accommodate the pulse
          height: 100.0, // Make the marker taller to accommodate the pulse
          point: widget.position,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse animation effect
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: 1.0 - _pulseAnimation.value * 0.9,
                    child: Container(
                      width: _pulseAnimation.value * 60,
                      height: _pulseAnimation.value * 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pulseColor,
                      ),
                    ),
                  );
                },
              ),
              
              // User location circle with border
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
                // Add directional indicator if heading is available
                child: widget.heading != null
                    ? Transform.rotate(
                        angle: (widget.heading! * math.pi / 180),
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 14,
                        ),
                      )
                    : null,
              ),
              
              // Subtle elevation shadow to make it appear above the map
              Positioned(
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.black.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 