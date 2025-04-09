import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A custom map layer that renders enhanced 2.5D terrain with dynamic elevation
/// and shadows that respond to tilt and rotation.
class TerrainLayer extends StatefulWidget {
  final Color baseColor;
  final Color highlightColor;
  final int detailLevel;
  final double tiltFactor;
  
  const TerrainLayer({
    Key? key,
    this.baseColor = const Color(0xFF3A3A3A),
    this.highlightColor = const Color(0xFF4A4A4A),
    this.detailLevel = 2,
    this.tiltFactor = 1.0,
  }) : super(key: key);

  @override
  State<TerrainLayer> createState() => _TerrainLayerState();
}

class _TerrainLayerState extends State<TerrainLayer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );
    
    _elevationAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Create subtle continuous animation for terrain movement
    _animationController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _elevationAnimation,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: EnhancedTerrainPainter(
              baseColor: widget.baseColor,
              highlightColor: widget.highlightColor,
              detailLevel: widget.detailLevel,
              tiltFactor: widget.tiltFactor,
              elevationFactor: _elevationAnimation.value,
            ),
            size: Size.infinite,
          ),
        );
      }
    );
  }
}

/// Enhanced painter that renders terrain with dynamic 2.5D effects
class EnhancedTerrainPainter extends CustomPainter {
  final Color baseColor;
  final Color highlightColor;
  final int detailLevel;
  final double tiltFactor;
  final double elevationFactor;
  final math.Random _random = math.Random(42); // Consistent seed for terrain generation
  
  EnhancedTerrainPainter({
    required this.baseColor,
    required this.highlightColor,
    required this.detailLevel,
    required this.tiltFactor,
    required this.elevationFactor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Define base elements
    final mainPaint = Paint()..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2 * tiltFactor)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    // Generate terrain sections with different elevations for true 2.5D effect
    final sections = detailLevel * 3;
    final sectionWidth = size.width / sections;
    
    // Draw multiple terrain layers with depth
    for (int layer = 0; layer < 3; layer++) {
      final layerOffset = layer * 50.0;
      final layerElevation = elevationFactor * (1.0 - (layer * 0.2));
      final layerOpacity = 1.0 - (layer * 0.25);
      
      // Create a gradient for this terrain layer
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          highlightColor.withOpacity(layerOpacity),
          baseColor.withOpacity(layerOpacity),
        ],
      );
      
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      mainPaint.shader = gradient.createShader(rect);
      
      // Create path for this terrain layer
      final path = Path();
      path.moveTo(0, size.height);
      
      // Generate a smoother, more natural terrain profile
      double lastX = 0;
      double lastY = size.height;
      
      for (int i = 0; i <= sections * 2; i++) {
        final progress = i / (sections * 2);
        final x = progress * size.width;
        
        // Create varied terrain heights based on noise and detail level
        final rawHeight = (_noise(progress * 5, layer * 0.5) * 0.5 + 0.5) * 
                          size.height * 0.25 * layerElevation;
        
        // Apply additional height variation based on detail level
        final detailNoise = detailLevel > 1 ? 
                           (_noise(progress * 20, layer * 1.5) * 0.5 + 0.5) * 
                           size.height * 0.05 * layerElevation : 0.0;
        
        final heightOffset = rawHeight + detailNoise;
        
        // Create more points for higher detail levels
        if (i % (4 - detailLevel) == 0 || i == 0 || i == sections * 2) {
          path.lineTo(x, size.height - heightOffset - layerOffset);
          lastX = x;
          lastY = size.height - heightOffset - layerOffset;
        }
      }
      
      path.lineTo(size.width, size.height);
      path.close();
      
      // Draw shadow first for depth effect
      if (tiltFactor > 0.2) {
        final shadowPath = Path.from(path);
        canvas.save();
        canvas.translate(4.0 * tiltFactor, 8.0 * tiltFactor);
        canvas.drawPath(shadowPath, shadowPaint);
        canvas.restore();
      }
      
      // Draw the terrain layer
      canvas.drawPath(path, mainPaint);
      
      // Add subtle noise texture for higher detail levels
      if (detailLevel >= 3) {
        _addTerrainTexture(canvas, path, size, layer);
      }
    }
  }
  
  // Simple Perlin-like noise function
  double _noise(double x, double y) {
    return math.sin(x * 12.9898 + y * 78.233) * 43758.5453 % 1;
  }
  
  // Add texture details to terrain
  void _addTerrainTexture(Canvas canvas, Path terrainPath, Size size, int layer) {
    final texturePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    // Clip to terrain path to ensure texture stays within terrain
    canvas.save();
    canvas.clipPath(terrainPath);
    
    // Add subtle noise dots for texture
    for (int i = 0; i < 100 * detailLevel; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = 1.0 + _random.nextDouble() * 2.0;
      
      canvas.drawCircle(Offset(x, y), radius, texturePaint);
    }
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(EnhancedTerrainPainter oldDelegate) {
    return oldDelegate.detailLevel != detailLevel ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.highlightColor != highlightColor ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.elevationFactor != elevationFactor;
  }
} 