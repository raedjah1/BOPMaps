import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../config/themes.dart';

class AuraEffectWidget extends StatefulWidget {
  final double radius;
  final LatLng center;
  final MapboxMapController? mapController;
  
  const AuraEffectWidget({
    Key? key,
    required this.radius,
    required this.center,
    required this.mapController,
  }) : super(key: key);

  @override
  State<AuraEffectWidget> createState() => _AuraEffectWidgetState();
}

class _AuraEffectWidgetState extends State<AuraEffectWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  double? _screenX;
  double? _screenY;
  double? _screenRadius;
  
  @override
  void initState() {
    super.initState();
    
    // Create animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    // Create pulse animation
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start pulsing animation
    _animationController.repeat(reverse: true);
    
    // Calculate initial position
    _updatePosition();
  }
  
  @override
  void didUpdateWidget(AuraEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update position when center changes
    if (oldWidget.center != widget.center || oldWidget.radius != widget.radius) {
      _updatePosition();
    }
  }
  
  // Update screen position based on map coordinates
  void _updatePosition() {
    if (widget.mapController == null) return;
    
    try {
      // Convert geo coordinates to screen coordinates
      final screenCoords = widget.mapController!.toScreenLocation(widget.center);
      
      // Calculate screen radius
      final LatLng radiusPoint = LatLng(
        widget.center.latitude,
        widget.center.longitude + widget.radius / 111000, // approximate 1 degree = 111km
      );
      final screenRadiusPoint = widget.mapController!.toScreenLocation(radiusPoint);
      
      // Calculate radius in screen pixels
      final pixelRadius = (screenCoords.x - screenRadiusPoint.x).abs();
      
      setState(() {
        _screenX = screenCoords.x;
        _screenY = screenCoords.y;
        _screenRadius = pixelRadius;
      });
    } catch (e) {
      print('Error calculating aura position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If position not calculated yet or controller not ready
    if (_screenX == null || _screenY == null || _screenRadius == null || widget.mapController == null) {
      return const SizedBox.shrink();
    }
    
    // Listen to camera position changes
    widget.mapController!.cameraPosition.addListener(_updatePosition);
    
    return Positioned(
      left: _screenX! - _screenRadius!,
      top: _screenY! - _screenRadius!,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: _screenRadius! * 2,
            height: _screenRadius! * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2 * _pulseAnimation.value),
                  AppTheme.primaryColor.withOpacity(0.1 * _pulseAnimation.value),
                  AppTheme.primaryColor.withOpacity(0.05 * _pulseAnimation.value),
                  Colors.transparent,
                ],
                stops: const [0.3, 0.6, 0.8, 1.0],
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3 * _pulseAnimation.value),
                width: 2,
              ),
            ),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    if (widget.mapController != null) {
      widget.mapController!.cameraPosition.removeListener(_updatePosition);
    }
    super.dispose();
  }
} 