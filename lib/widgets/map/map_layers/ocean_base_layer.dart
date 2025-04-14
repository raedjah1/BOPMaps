import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../map_styles.dart';

/// A specialized layer that renders a beautiful ocean background for the map.
/// This is especially useful for zoomed-out views where we want a consistent
/// ocean appearance across the entire visible area.
class OceanBaseLayer extends StatefulWidget {
  /// The current zoom level of the map
  final double zoomLevel;
  
  /// The visible bounds of the map
  final LatLngBounds visibleBounds;
  
  /// Tilt factor for 2.5D effect (0.0-1.0)
  final double tiltFactor;
  
  /// Whether to use animated wave effects
  final bool animated;
  
  /// Primary ocean color, defaults to the design system color
  final Color oceanColor;
  
  const OceanBaseLayer({
    Key? key,
    required this.zoomLevel,
    required this.visibleBounds,
    this.tiltFactor = 0.0,
    this.animated = true,
    this.oceanColor = MapStyles.oceanDeepColor,
  }) : super(key: key);

  @override
  State<OceanBaseLayer> createState() => _OceanBaseLayerState();
}

class _OceanBaseLayerState extends State<OceanBaseLayer> with SingleTickerProviderStateMixin {
  // Animation controller for water ripple effect
  late AnimationController _animationController;
  late Animation<double> _rippleAnimation;
  
  // Flag to determine whether to show detailed effect
  bool _showDetailed = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    
    // Create ripple animation
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Set up animation to repeat
    _animationController.repeat(reverse: true);
    
    // Determine detail level
    _updateDetailLevel();
  }
  
  @override
  void didUpdateWidget(OceanBaseLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation state
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    }
    
    // Update detail level if zoom changed
    if (widget.zoomLevel != oldWidget.zoomLevel) {
      _updateDetailLevel();
    }
  }
  
  void _updateDetailLevel() {
    setState(() {
      // Only show detailed ocean with ripples when zoomed in
      _showDetailed = widget.zoomLevel > 8.0;
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether to use animation based on settings and zoom level
    final useAnimation = widget.animated && _showDetailed;
    
    // Base ocean view doesn't need animation for performance
    if (!useAnimation) {
      return CustomPaint(
        painter: OceanPainter(
          oceanColor: widget.oceanColor,
          tiltFactor: widget.tiltFactor,
          rippleValue: 0.0,
          showDetailed: _showDetailed,
        ),
        size: Size.infinite,
      );
    }
    
    // Use animated ocean for higher zoom levels
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: OceanPainter(
            oceanColor: widget.oceanColor,
            tiltFactor: widget.tiltFactor,
            rippleValue: _rippleAnimation.value,
            showDetailed: _showDetailed,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter to render the ocean
class OceanPainter extends CustomPainter {
  final Color oceanColor;
  final double tiltFactor;
  final double rippleValue;
  final bool showDetailed;
  
  // For the wave pattern
  final int _waveCount = 5;
  
  OceanPainter({
    required this.oceanColor,
    required this.tiltFactor,
    required this.rippleValue,
    required this.showDetailed,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire canvas with the base ocean color
    final Paint oceanPaint = Paint()
      ..color = oceanColor
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Offset.zero & size, oceanPaint);
    
    // Skip detailed rendering if not needed (for performance)
    if (!showDetailed) return;
    
    // Add a subtle gradient overlay for depth effect
    final Rect gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          oceanColor.withOpacity(0.8),
          MapStyles.oceanGradient[1].withOpacity(0.9),
          MapStyles.oceanGradient[2].withOpacity(0.85),
        ],
      ).createShader(gradientRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(gradientRect, gradientPaint);
    
    // Add ripple waves if detailed view is enabled
    if (tiltFactor > 0.1) {
      _drawOceanRipples(canvas, size);
    }
  }
  
  /// Draw subtle ripple waves on the ocean
  void _drawOceanRipples(Canvas canvas, Size size) {
    final Paint ripplePaint = Paint()
      ..color = Colors.white.withOpacity(0.05 + (0.03 * rippleValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Create wave patterns based on size
    final double baseY = size.height * 0.6; // Start waves at 60% of the height
    
    for (int i = 0; i < _waveCount; i++) {
      final path = Path();
      
      // Calculate wave parameters
      final double amplitude = 4.0 + (i * 0.8) + (rippleValue * 2.0);
      final double frequency = 0.02 - (i * 0.002);
      final double phaseShift = rippleValue * math.pi * 2 * (i % 2 == 0 ? 1 : -1);
      final double verticalOffset = i * 20.0 * (1 + tiltFactor);
      
      // Start drawing the wave
      path.moveTo(0, baseY + verticalOffset);
      
      // Draw the wave using a sine function
      for (double x = 0; x <= size.width; x += 5) {
        final y = baseY + verticalOffset + 
                  amplitude * math.sin((x * frequency) + phaseShift);
        path.lineTo(x, y);
      }
      
      // Draw the wave
      canvas.drawPath(path, ripplePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant OceanPainter oldDelegate) {
    return oldDelegate.rippleValue != rippleValue ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.oceanColor != oceanColor ||
           oldDelegate.showDetailed != showDetailed;
  }
} 