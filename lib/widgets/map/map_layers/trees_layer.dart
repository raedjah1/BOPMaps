import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A custom map layer that renders trees and other vegetation
/// with advanced 2.5D effects that respond to tilt changes.
class TreesLayer extends StatefulWidget {
  final Color foliageColor;
  final Color trunkColor;
  final int detailLevel;
  final double tiltFactor;
  
  const TreesLayer({
    Key? key,
    this.foliageColor = const Color(0xFF2E7D32), // Dark green
    this.trunkColor = const Color(0xFF5D4037),   // Brown
    this.detailLevel = 2,
    this.tiltFactor = 1.0,
  }) : super(key: key);

  @override
  State<TreesLayer> createState() => _TreesLayerState();
}

class _TreesLayerState extends State<TreesLayer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _swayAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _swayAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Create gentle swaying animation for trees
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
      animation: _swayAnimation,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: TreesPainter(
              foliageColor: widget.foliageColor,
              trunkColor: widget.trunkColor,
              detailLevel: widget.detailLevel,
              tiltFactor: widget.tiltFactor,
              swayFactor: _swayAnimation.value,
            ),
            size: Size.infinite,
          ),
        );
      }
    );
  }
}

/// Painter that renders trees and vegetation with 2.5D effects
class TreesPainter extends CustomPainter {
  final Color foliageColor;
  final Color trunkColor;
  final int detailLevel;
  final double tiltFactor;
  final double swayFactor;
  final math.Random _random = math.Random(123); // Different seed than other layers
  
  // Tree types for variety
  final List<String> _treeTypes = ['pine', 'oak', 'bush', 'palm'];
  
  TreesPainter({
    required this.foliageColor,
    required this.trunkColor,
    required this.detailLevel,
    required this.tiltFactor,
    required this.swayFactor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Number of trees to render depends on detail level
    final int treeCount;
    if (detailLevel == 1) {
      treeCount = 15;   // Low detail
    } else if (detailLevel == 2) {
      treeCount = 25;   // Medium detail
    } else {
      treeCount = 40;   // High detail
    }
    
    // Create clusters of trees rather than random placement
    final clusters = 5 + detailLevel;
    final List<Offset> clusterCenters = [];
    
    // Generate cluster centers along the bottom and sides of the screen
    for (int i = 0; i < clusters; i++) {
      final clusterX = (i / clusters) * size.width;
      final clusterY = size.height * (0.6 + 0.4 * _random.nextDouble());
      clusterCenters.add(Offset(clusterX, clusterY));
    }
    
    // Add random cluster centers
    for (int i = 0; i < clusters / 2; i++) {
      final clusterX = _random.nextDouble() * size.width;
      final clusterY = size.height * (0.5 + 0.5 * _random.nextDouble());
      clusterCenters.add(Offset(clusterX, clusterY));
    }
    
    // Sort clusters by depth for proper drawing order
    clusterCenters.sort((a, b) => b.dy.compareTo(a.dy));
    
    // Draw trees in each cluster
    final treesPerCluster = treeCount ~/ clusterCenters.length;
    for (final clusterCenter in clusterCenters) {
      for (int i = 0; i < treesPerCluster; i++) {
        // Tree position relative to cluster center
        final distance = 20.0 + 80.0 * _random.nextDouble();
        final angle = _random.nextDouble() * 2 * math.pi;
        final x = clusterCenter.dx + math.cos(angle) * distance;
        final y = clusterCenter.dy + math.sin(angle) * distance * 0.5; // Elliptical distribution
        
        // Tree size - larger in foreground, smaller in background
        final foregroundFactor = y / size.height;
        final treeSize = 20 + 40 * foregroundFactor * (_random.nextDouble() * 0.4 + 0.8);
        
        // Select tree type with weighted probability
        final treeTypeIndex = _getWeightedTreeType(clusterCenter, size);
        final treeType = _treeTypes[treeTypeIndex];
        
        // Draw tree with sway animation
        _drawTree(
          canvas, 
          x, 
          y, 
          treeSize, 
          treeType, 
          foregroundFactor,
        );
      }
    }
    
    // Draw additional ground vegetation for higher detail levels
    if (detailLevel >= 3) {
      _drawGroundVegetation(canvas, size);
    }
  }
  
  // Return a tree type index with weighted probability based on location
  int _getWeightedTreeType(Offset position, Size size) {
    // Near edges of screen, more likely to have pines and bushes
    final edgeFactor = math.min(
      math.min(position.dx, size.width - position.dx),
      math.min(position.dy, size.height - position.dy)
    ) / math.min(size.width, size.height);
    
    // Bottom of screen more likely to have palms and oaks
    final bottomFactor = position.dy / size.height;
    
    if (edgeFactor < 0.2) {
      // Near edge - mostly pines and bushes
      return _random.nextDouble() < 0.7 ? 0 : 2; // pine or bush
    } else if (bottomFactor > 0.8) {
      // Near bottom - more palms and oaks
      return _random.nextDouble() < 0.6 ? 3 : 1; // palm or oak
    } else {
      // Elsewhere - random distribution
      return _random.nextInt(_treeTypes.length);
    }
  }
  
  // Draw a tree with the given properties
  void _drawTree(
    Canvas canvas, 
    double x, 
    double y, 
    double size, 
    String treeType,
    double foregroundFactor
  ) {
    // Apply perspective offsets based on tilt
    final perspectiveOffsetX = tiltFactor * size * swayFactor * 2;
    final perspectiveOffsetY = tiltFactor * size * 0.05;
    
    // Apply additional sway to the tree based on its type
    final treeSway = swayFactor * (treeType == 'pine' || treeType == 'palm' ? 2.0 : 1.0);
    
    // Add shadow for 3D effect
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1 * tiltFactor * foregroundFactor)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    final shadowOffset = 5.0 * tiltFactor;
    
    // Shadow is more pronounced with higher tilt
    if (tiltFactor > 0.2) {
      canvas.save();
      canvas.translate(shadowOffset, shadowOffset);
      
      // Draw shadow based on tree type
      switch (treeType) {
        case 'pine':
          _drawPineTreeShadow(canvas, x, y, size, shadowPaint);
          break;
        case 'oak':
          _drawOakTreeShadow(canvas, x, y, size, shadowPaint);
          break;
        case 'bush':
          _drawBushShadow(canvas, x, y, size, shadowPaint);
          break;
        case 'palm':
          _drawPalmTreeShadow(canvas, x, y, size, shadowPaint);
          break;
      }
      
      canvas.restore();
    }
    
    // Draw actual tree based on type
    switch (treeType) {
      case 'pine':
        _drawPineTree(canvas, x, y, size, treeSway, perspectiveOffsetX, perspectiveOffsetY);
        break;
      case 'oak':
        _drawOakTree(canvas, x, y, size, treeSway, perspectiveOffsetX, perspectiveOffsetY);
        break;
      case 'bush':
        _drawBush(canvas, x, y, size, treeSway, perspectiveOffsetX, perspectiveOffsetY);
        break;
      case 'palm':
        _drawPalmTree(canvas, x, y, size, treeSway, perspectiveOffsetX, perspectiveOffsetY);
        break;
    }
  }
  
  // Draw a pine tree
  void _drawPineTree(
    Canvas canvas, 
    double x, 
    double y, 
    double size, 
    double sway,
    double offsetX,
    double offsetY
  ) {
    final trunkWidth = size * 0.1;
    final trunkHeight = size * 0.4;
    final foliageWidth = size * 0.6;
    final foliageHeight = size * 0.8;
    
    // Trunk
    final trunkPaint = Paint()
      ..color = trunkColor
      ..style = PaintingStyle.fill;
    
    final trunkRect = Rect.fromLTWH(
      x - trunkWidth / 2 + (sway * size * 0.1), 
      y - trunkHeight, 
      trunkWidth, 
      trunkHeight,
    );
    
    canvas.drawRect(trunkRect, trunkPaint);
    
    // Pine foliage (triangular layers)
    final foliagePaint = Paint()
      ..color = foliageColor
      ..style = PaintingStyle.fill;
    
    final layers = 3;
    for (int i = 0; i < layers; i++) {
      final layerOffset = i * (foliageHeight / layers) * 0.8;
      final layerWidth = foliageWidth * (1.0 - i * 0.2);
      final layerHeight = foliageHeight * 0.6;
      
      final trianglePath = Path();
      // Add sway effect to the foliage
      final swayOffset = sway * size * 0.15 * (i + 1);
      
      trianglePath.moveTo(x + swayOffset, y - trunkHeight - layerOffset - layerHeight);
      trianglePath.lineTo(x - layerWidth / 2 + swayOffset, y - trunkHeight - layerOffset);
      trianglePath.lineTo(x + layerWidth / 2 + swayOffset, y - trunkHeight - layerOffset);
      trianglePath.close();
      
      // Make the color slightly darker for lower layers
      final layerColor = foliageColor.withOpacity(1.0 - i * 0.1);
      foliagePaint.color = layerColor;
      canvas.drawPath(trianglePath, foliagePaint);
    }
  }
  
  // Draw shadow for a pine tree
  void _drawPineTreeShadow(Canvas canvas, double x, double y, double size, Paint shadowPaint) {
    final foliageWidth = size * 0.6;
    final totalHeight = size * 1.2;
    
    final shadowPath = Path();
    shadowPath.moveTo(x, y - totalHeight * 0.8);
    shadowPath.lineTo(x - foliageWidth / 2, y);
    shadowPath.lineTo(x + foliageWidth / 2, y);
    shadowPath.close();
    
    canvas.drawPath(shadowPath, shadowPaint);
  }
  
  // Draw an oak tree (rounded foliage)
  void _drawOakTree(
    Canvas canvas, 
    double x, 
    double y, 
    double size, 
    double sway,
    double offsetX,
    double offsetY
  ) {
    final trunkWidth = size * 0.12;
    final trunkHeight = size * 0.4;
    final foliageRadius = size * 0.4;
    
    // Trunk with slight curve for sway
    final trunkPaint = Paint()
      ..color = trunkColor
      ..style = PaintingStyle.fill;
    
    final trunkPath = Path();
    trunkPath.moveTo(x, y);
    trunkPath.lineTo(x + (sway * size * 0.15), y - trunkHeight);
    trunkPath.lineTo(x + (sway * size * 0.15) + trunkWidth, y - trunkHeight);
    trunkPath.lineTo(x + trunkWidth, y);
    trunkPath.close();
    
    canvas.drawPath(trunkPath, trunkPaint);
    
    // Oak foliage (clusters of circles)
    final foliagePaint = Paint()
      ..color = foliageColor
      ..style = PaintingStyle.fill;
    
    // Main foliage
    canvas.drawCircle(
      Offset(x + (sway * size * 0.2), y - trunkHeight - foliageRadius * 0.8),
      foliageRadius,
      foliagePaint,
    );
    
    // Additional foliage clusters for more detail
    if (detailLevel >= 2) {
      final smallerRadius = foliageRadius * 0.6;
      
      canvas.drawCircle(
        Offset(x + smallerRadius * 0.5 + (sway * size * 0.25), y - trunkHeight - foliageRadius * 1.2),
        smallerRadius,
        foliagePaint,
      );
      
      canvas.drawCircle(
        Offset(x - smallerRadius * 0.5 + (sway * size * 0.15), y - trunkHeight - foliageRadius * 0.7),
        smallerRadius,
        foliagePaint,
      );
      
      canvas.drawCircle(
        Offset(x + smallerRadius * 0.7 + (sway * size * 0.3), y - trunkHeight - foliageRadius * 0.4),
        smallerRadius,
        foliagePaint,
      );
    }
  }
  
  // Draw shadow for an oak tree
  void _drawOakTreeShadow(Canvas canvas, double x, double y, double size, Paint shadowPaint) {
    final foliageRadius = size * 0.4;
    
    // Simple shadow as an oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y - size * 0.2),
        width: foliageRadius * 2,
        height: foliageRadius,
      ),
      shadowPaint,
    );
  }
  
  // Draw a bush (smaller with no trunk)
  void _drawBush(
    Canvas canvas, 
    double x, 
    double y, 
    double size, 
    double sway,
    double offsetX,
    double offsetY
  ) {
    final bushRadius = size * 0.3;
    
    // Bush foliage (multiple circles)
    final foliagePaint = Paint()
      ..color = foliageColor.withAlpha(230)
      ..style = PaintingStyle.fill;
    
    // Subtle sway for bushes
    final swayOffset = sway * size * 0.05;
    
    // Main bush shape
    canvas.drawCircle(
      Offset(x + swayOffset, y - bushRadius),
      bushRadius,
      foliagePaint,
    );
    
    // Additional foliage parts
    canvas.drawCircle(
      Offset(x + bushRadius * 0.4 + swayOffset, y - bushRadius * 1.1),
      bushRadius * 0.7,
      foliagePaint,
    );
    
    canvas.drawCircle(
      Offset(x - bushRadius * 0.4 + swayOffset, y - bushRadius * 0.9),
      bushRadius * 0.6,
      foliagePaint,
    );
    
    canvas.drawCircle(
      Offset(x + swayOffset, y - bushRadius * 0.4),
      bushRadius * 0.7,
      foliagePaint,
    );
  }
  
  // Draw shadow for a bush
  void _drawBushShadow(Canvas canvas, double x, double y, double size, Paint shadowPaint) {
    final bushRadius = size * 0.3;
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y - size * 0.1),
        width: bushRadius * 2,
        height: bushRadius * 0.7,
      ),
      shadowPaint,
    );
  }
  
  // Draw a palm tree
  void _drawPalmTree(
    Canvas canvas, 
    double x, 
    double y, 
    double size, 
    double sway,
    double offsetX,
    double offsetY
  ) {
    final trunkWidth = size * 0.08;
    final trunkHeight = size * 0.6;
    
    // Curved trunk for palm
    final trunkPaint = Paint()
      ..color = trunkColor.withRed(trunkColor.red + 20)
      ..style = PaintingStyle.fill;
    
    final trunkPath = Path();
    // Create a curved trunk with sway
    trunkPath.moveTo(x, y);
    
    // Control points for the curve
    final controlX1 = x + (sway * size * 0.3);
    final controlY1 = y - trunkHeight * 0.6;
    final controlX2 = x + (sway * size * 0.6);
    final controlY2 = y - trunkHeight * 0.8;
    
    // Endpoint of the curve
    final endX = x + (sway * size * 0.5);
    final endY = y - trunkHeight;
    
    // Draw the curved trunk
    trunkPath.cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);
    trunkPath.lineTo(endX + trunkWidth, endY);
    
    // Return curve
    trunkPath.cubicTo(
      controlX2 + trunkWidth, controlY2,
      controlX1 + trunkWidth, controlY1,
      x + trunkWidth, y
    );
    
    trunkPath.close();
    canvas.drawPath(trunkPath, trunkPaint);
    
    // Palm leaves
    final leafPaint = Paint()
      ..color = foliageColor.withGreen(foliageColor.green + 10)
      ..style = PaintingStyle.fill;
    
    // Draw several leaves in different directions
    final leafCount = 5 + detailLevel;
    final leafLength = size * 0.6;
    final leafWidth = size * 0.08;
    
    for (int i = 0; i < leafCount; i++) {
      final angle = (i / leafCount) * 2 * math.pi;
      // Add sway effect to leaf angle
      final adjustedAngle = angle + (sway * 0.2);
      
      final leafPath = Path();
      leafPath.moveTo(endX, endY);
      
      // Curved leaf shape
      final leafEndX = endX + math.cos(adjustedAngle) * leafLength;
      final leafEndY = endY + math.sin(adjustedAngle) * leafLength;
      
      // Control points for leaf curve
      final leafControlX = endX + math.cos(adjustedAngle) * leafLength * 0.5;
      final leafControlY = endY + math.sin(adjustedAngle) * leafLength * 0.5;
      
      // Perpendicular direction for leaf width
      final perpX = math.cos(adjustedAngle + math.pi / 2) * leafWidth;
      final perpY = math.sin(adjustedAngle + math.pi / 2) * leafWidth;
      
      // Draw the leaf as a curved shape
      leafPath.quadraticBezierTo(
        leafControlX + perpX * 0.3, 
        leafControlY + perpY * 0.3,
        leafEndX, 
        leafEndY
      );
      
      leafPath.quadraticBezierTo(
        leafControlX - perpX * 0.3, 
        leafControlY - perpY * 0.3,
        endX, 
        endY
      );
      
      leafPath.close();
      canvas.drawPath(leafPath, leafPaint);
    }
  }
  
  // Draw shadow for a palm tree
  void _drawPalmTreeShadow(Canvas canvas, double x, double y, double size, Paint shadowPaint) {
    final trunkHeight = size * 0.6;
    final leafLength = size * 0.5;
    
    // Simple circular shadow for the palm crown
    canvas.drawCircle(
      Offset(x, y - trunkHeight * 0.8),
      leafLength * 0.8,
      shadowPaint,
    );
  }
  
  // Draw ground vegetation for higher detail levels
  void _drawGroundVegetation(Canvas canvas, Size size) {
    final grassPaint = Paint()
      ..color = foliageColor.withGreen(foliageColor.green + 30).withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final grassCount = 200 + (detailLevel * 100);
    
    for (int i = 0; i < grassCount; i++) {
      final x = _random.nextDouble() * size.width;
      final y = size.height * (0.7 + _random.nextDouble() * 0.3);
      
      final grassHeight = 4 + _random.nextDouble() * 8;
      final sway = swayFactor * 3 * tiltFactor;
      
      // Simple grass blade
      final blade = Path();
      blade.moveTo(x, y);
      blade.quadraticBezierTo(
        x + sway, 
        y - grassHeight * 0.6, 
        x + sway * 1.5, 
        y - grassHeight
      );
      
      canvas.drawPath(blade, grassPaint);
    }
  }
  
  @override
  bool shouldRepaint(TreesPainter oldDelegate) {
    return oldDelegate.detailLevel != detailLevel ||
           oldDelegate.foliageColor != foliageColor ||
           oldDelegate.trunkColor != trunkColor ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.swayFactor != swayFactor;
  }
} 