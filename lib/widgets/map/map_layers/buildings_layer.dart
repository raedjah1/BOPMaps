import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A custom map layer that renders buildings with Level of Detail (LOD)
/// optimization based on the current zoom level.
class BuildingsLayer extends StatelessWidget {
  final Color buildingBaseColor;
  final Color buildingTopColor;
  final int detailLevel;
  
  const BuildingsLayer({
    Key? key,
    this.buildingBaseColor = const Color(0xFF2A2A2A),
    this.buildingTopColor = const Color(0xFF4A4A4A),
    this.detailLevel = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: BuildingsPainter(
          baseColor: buildingBaseColor,
          topColor: buildingTopColor,
          detailLevel: detailLevel,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Painter that renders simplified buildings with 2.5D effect
class BuildingsPainter extends CustomPainter {
  final Color baseColor;
  final Color topColor;
  final int detailLevel;
  final math.Random _random = math.Random(42); // Consistent seed for reproducibility
  
  BuildingsPainter({
    required this.baseColor,
    required this.topColor,
    required this.detailLevel,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // In a real implementation, we would render buildings based on
    // GeoJSON data from the backend. For now, this is just a placeholder
    // that simulates buildings with different heights.
    
    // Number of buildings to render depends on detail level
    final int buildingCount;
    if (detailLevel == 1) {
      buildingCount = 10;   // Low detail
    } else if (detailLevel == 2) {
      buildingCount = 25;   // Medium detail
    } else {
      buildingCount = 50;   // High detail
    }
    
    // Generate placeholder buildings
    for (int i = 0; i < buildingCount; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final width = 20 + _random.nextDouble() * 40;
      final height = 30 + _random.nextDouble() * 50;
      
      _drawBuilding(canvas, x, y, width, height);
    }
  }
  
  // Draw a single building with 2.5D effect
  void _drawBuilding(Canvas canvas, double x, double y, double width, double height) {
    final buildingPaint = Paint()..style = PaintingStyle.fill;
    final topPaint = Paint()..color = topColor;
    
    // Building main face (front)
    final frontPath = Path();
    frontPath.moveTo(x, y);
    frontPath.lineTo(x, y - height);
    frontPath.lineTo(x + width, y - height);
    frontPath.lineTo(x + width, y);
    frontPath.close();
    
    buildingPaint.color = baseColor;
    canvas.drawPath(frontPath, buildingPaint);
    
    // Building top (roof)
    final topPath = Path();
    topPath.moveTo(x, y - height);
    topPath.lineTo(x + width * 0.1, y - height - width * 0.1);
    topPath.lineTo(x + width * 1.1, y - height - width * 0.1);
    topPath.lineTo(x + width, y - height);
    topPath.close();
    
    canvas.drawPath(topPath, topPaint);
    
    // Building side (right face) - only if detail level is medium or high
    if (detailLevel >= 2) {
      final sidePath = Path();
      sidePath.moveTo(x + width, y);
      sidePath.lineTo(x + width, y - height);
      sidePath.lineTo(x + width * 1.1, y - height - width * 0.1);
      sidePath.lineTo(x + width * 1.1, y - width * 0.1);
      sidePath.close();
      
      buildingPaint.color = baseColor.withOpacity(0.7);
      canvas.drawPath(sidePath, buildingPaint);
    }
    
    // Add windows if detail level is high
    if (detailLevel >= 3) {
      final windowPaint = Paint()..color = Colors.yellow.withOpacity(0.3);
      final windowSize = width * 0.15;
      final windowSpacing = width * 0.25;
      final windowRows = (height / windowSpacing).floor() - 1;
      final windowCols = (width / windowSpacing).floor() - 1;
      
      for (int row = 0; row < windowRows; row++) {
        for (int col = 0; col < windowCols; col++) {
          final windowX = x + (col + 1) * windowSpacing;
          final windowY = y - (row + 1) * windowSpacing;
          
          // Only draw some windows randomly
          if (_random.nextBool()) {
            canvas.drawRect(
              Rect.fromLTWH(windowX, windowY - windowSize, windowSize, windowSize),
              windowPaint,
            );
          }
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(BuildingsPainter oldDelegate) {
    return oldDelegate.detailLevel != detailLevel ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.topColor != topColor;
  }
} 