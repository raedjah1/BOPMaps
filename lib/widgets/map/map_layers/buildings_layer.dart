import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A custom map layer that renders buildings with Level of Detail (LOD)
/// optimization based on the current zoom level.
class BuildingsLayer extends StatefulWidget {
  final Color buildingBaseColor;
  final Color buildingTopColor;
  final int detailLevel;
  final double tiltFactor;
  
  const BuildingsLayer({
    Key? key,
    this.buildingBaseColor = const Color(0xFF2A2A2A),
    this.buildingTopColor = const Color(0xFF4A4A4A),
    this.detailLevel = 2,
    this.tiltFactor = 1.0,
  }) : super(key: key);

  @override
  State<BuildingsLayer> createState() => _BuildingsLayerState();
}

class _BuildingsLayerState extends State<BuildingsLayer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _lightingAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    );
    
    _lightingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Create a continuous animation cycle for lighting changes
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
      animation: _lightingAnimation,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: Enhanced3DBuildingsPainter(
              baseColor: widget.buildingBaseColor,
              topColor: widget.buildingTopColor,
              detailLevel: widget.detailLevel,
              tiltFactor: widget.tiltFactor,
              lightingFactor: _lightingAnimation.value,
            ),
            size: Size.infinite,
          ),
        );
      }
    );
  }
}

/// Enhanced painter that renders buildings with advanced 2.5D effects
class Enhanced3DBuildingsPainter extends CustomPainter {
  final Color baseColor;
  final Color topColor;
  final int detailLevel;
  final double tiltFactor;
  final double lightingFactor;
  final math.Random _random = math.Random(42); // Consistent seed for reproducibility
  
  // Building types for more variety
  final List<String> _buildingTypes = ['office', 'apartment', 'skyscraper', 'store'];
  
  Enhanced3DBuildingsPainter({
    required this.baseColor,
    required this.topColor,
    required this.detailLevel,
    required this.tiltFactor,
    required this.lightingFactor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Number of buildings to render depends on detail level
    final int buildingCount;
    if (detailLevel == 1) {
      buildingCount = 8;   // Low detail
    } else if (detailLevel == 2) {
      buildingCount = 15;  // Medium detail
    } else {
      buildingCount = 25;  // High detail
    }
    
    // Sort buildings by position to draw them in the correct order
    final buildingData = <Map<String, dynamic>>[];
    
    // Generate buildings with varied attributes
    for (int i = 0; i < buildingCount; i++) {
      // Distribute buildings more strategically around the screen
      final section = i % 4;  // Divide screen into 4 sections
      final sectionWidth = size.width / 4;
      final sectionHeight = size.height / 4;
      
      final x = (section * sectionWidth) + (_random.nextDouble() * sectionWidth * 0.8);
      final y = _random.nextDouble() * size.height * 0.8 + (size.height * 0.2);
      
      final width = 15 + _random.nextDouble() * 35 * (detailLevel / 2);
      
      // Vary heights by building type and location
      final baseHeight = 30 + _random.nextDouble() * 40;
      final multiplier = 1.0 + (section == 1 ? 1.5 : (section == 2 ? 0.8 : 1.0));
      final height = baseHeight * multiplier;
      
      // Select building type
      final buildingType = _buildingTypes[_random.nextInt(_buildingTypes.length)];
      
      // Record building data for sorted drawing
      buildingData.add({
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'type': buildingType,
        'depth': y + x / size.width, // Used for sorting
      });
    }
    
    // Sort buildings by depth for proper overlapping based on tilt
    if (tiltFactor > 0.2) {
      buildingData.sort((a, b) => b['depth'].compareTo(a['depth']));
    }
    
    // Draw buildings in correct order
    for (final building in buildingData) {
      _drawEnhancedBuilding(
        canvas, 
        building['x'], 
        building['y'], 
        building['width'], 
        building['height'], 
        building['type'],
      );
    }
    
    // Add additional atmospheric effects for high detail
    if (detailLevel >= 3 && tiltFactor > 0.3) {
      _addAtmosphericEffects(canvas, size);
    }
  }
  
  // Draw an enhanced building with detailed 2.5D effects
  void _drawEnhancedBuilding(
    Canvas canvas, 
    double x, 
    double y, 
    double width, 
    double height, 
    String buildingType
  ) {
    // Apply perspective adjustments based on tilt
    final perspectiveOffsetX = tiltFactor * width * 0.1;
    final perspectiveOffsetY = tiltFactor * height * 0.05;
    
    // Base colors modified by lighting
    final adjustedBaseColor = _adjustColorWithLighting(baseColor);
    final adjustedTopColor = _adjustColorWithLighting(topColor);
    
    // Create gradient color for sides based on lighting
    final sideGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        adjustedBaseColor.withOpacity(0.9),
        adjustedBaseColor.withOpacity(0.7),
      ],
    );
    
    // Front face with shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2 * tiltFactor)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    // Draw shadow first
    if (tiltFactor > 0.2) {
      final shadowPath = Path();
      shadowPath.moveTo(x + perspectiveOffsetX, y + perspectiveOffsetY);
      shadowPath.lineTo(x + perspectiveOffsetX, y - height + perspectiveOffsetY);
      shadowPath.lineTo(x + width + perspectiveOffsetX, y - height + perspectiveOffsetY);
      shadowPath.lineTo(x + width + perspectiveOffsetX, y + perspectiveOffsetY);
      shadowPath.close();
      
      canvas.save();
      canvas.translate(3.0 * tiltFactor, 5.0 * tiltFactor);
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.restore();
    }
    
    // Building main face (front)
    final frontPath = Path();
    frontPath.moveTo(x, y);
    frontPath.lineTo(x, y - height);
    frontPath.lineTo(x + width, y - height);
    frontPath.lineTo(x + width, y);
    frontPath.close();
    
    final frontPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = adjustedBaseColor;
    
    canvas.drawPath(frontPath, frontPaint);
    
    // Building top (roof) with enhanced effect
    final roofHeight = width * (buildingType == 'skyscraper' ? 0.15 : 0.1);
    final topPath = Path();
    topPath.moveTo(x, y - height);
    topPath.lineTo(x + perspectiveOffsetX, y - height - roofHeight);
    topPath.lineTo(x + width + perspectiveOffsetX, y - height - roofHeight);
    topPath.lineTo(x + width, y - height);
    topPath.close();
    
    final topPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = adjustedTopColor;
    
    canvas.drawPath(topPath, topPaint);
    
    // Right side face with gradient
    final rightSidePath = Path();
    rightSidePath.moveTo(x + width, y);
    rightSidePath.lineTo(x + width, y - height);
    rightSidePath.lineTo(x + width + perspectiveOffsetX, y - height - roofHeight);
    rightSidePath.lineTo(x + width + perspectiveOffsetX, y - roofHeight);
    rightSidePath.close();
    
    final rightSidePaint = Paint()
      ..style = PaintingStyle.fill;
    
    final rightRect = Rect.fromLTWH(
      x + width, 
      y - height, 
      perspectiveOffsetX, 
      height,
    );
    
    rightSidePaint.shader = sideGradient.createShader(rightRect);
    canvas.drawPath(rightSidePath, rightSidePaint);
    
    // Add windows with lighting effects
    _addWindows(canvas, x, y, width, height, buildingType);
    
    // Add details based on building type
    if (detailLevel >= 2) {
      _addBuildingDetails(canvas, x, y, width, height, buildingType);
    }
  }
  
  // Add windows with varied lighting based on time of day
  void _addWindows(
    Canvas canvas, 
    double x, 
    double y, 
    double width, 
    double height, 
    String buildingType
  ) {
    // Window configuration based on building type
    int rows, cols;
    double windowOpacity;
    Color windowColor;
    
    switch (buildingType) {
      case 'skyscraper':
        rows = (height / 15).floor();
        cols = (width / 12).floor();
        windowOpacity = 0.5 + (lightingFactor * 0.5);
        windowColor = Colors.yellow.withOpacity(windowOpacity);
        break;
      case 'office':
        rows = (height / 20).floor();
        cols = (width / 15).floor();
        windowOpacity = 0.3 + (lightingFactor * 0.4);
        windowColor = Colors.white.withOpacity(windowOpacity);
        break;
      case 'apartment':
        rows = (height / 25).floor();
        cols = (width / 20).floor();
        windowOpacity = 0.2 + (lightingFactor * 0.6);
        windowColor = Colors.amber.withOpacity(windowOpacity);
        break;
      default: // store
        rows = (height / 30).floor();
        cols = (width / 25).floor();
        windowOpacity = 0.4 + (lightingFactor * 0.4);
        windowColor = Colors.blue.withOpacity(windowOpacity);
    }
    
    // Ensure at least 1 window
    rows = math.max(1, rows);
    cols = math.max(1, cols);
    
    final windowWidth = width / (cols + 1);
    final windowHeight = height / (rows + 1);
    
    final windowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = windowColor;
    
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // Add some randomness to window lighting
        if (detailLevel >= 3) {
          // Higher detail means more varied window lighting
          if (_random.nextDouble() > (0.3 + lightingFactor * 0.4)) {
            windowPaint.color = windowColor.withOpacity(windowOpacity * 0.3);
          } else {
            windowPaint.color = windowColor;
          }
        }
        
        final windowX = x + (col + 1) * (width / (cols + 1));
        final windowY = y - (row + 1) * (height / (rows + 1));
        
        canvas.drawRect(
          Rect.fromLTWH(windowX, windowY, windowWidth * 0.6, windowHeight * 0.6),
          windowPaint,
        );
      }
    }
  }
  
  // Add specific building details based on type
  void _addBuildingDetails(
    Canvas canvas, 
    double x, 
    double y, 
    double width, 
    double height, 
    String buildingType
  ) {
    if (detailLevel < 2) return;
    
    switch (buildingType) {
      case 'skyscraper':
        // Add antenna on top
        if (detailLevel >= 3) {
          final antennaPaint = Paint()
            ..color = Colors.grey.shade700
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
            
          final centerX = x + width / 2;
          canvas.drawLine(
            Offset(centerX, y - height - (width * 0.1)), 
            Offset(centerX, y - height - (width * 0.25)), 
            antennaPaint,
          );
        }
        break;
        
      case 'office':
        // Add entrance at bottom
        final entrancePaint = Paint()
          ..color = Colors.grey.shade800;
          
        canvas.drawRect(
          Rect.fromLTWH(x + width * 0.4, y - height * 0.15, width * 0.2, height * 0.15),
          entrancePaint,
        );
        break;
        
      case 'apartment':
        // Add balconies
        if (detailLevel >= 3) {
          final balconyPaint = Paint()
            ..color = Colors.grey.shade600;
            
          var rows = (height / 35).floor();
          rows = math.max(1, rows);
          
          for (int row = 0; row < rows; row++) {
            final balconyY = y - (row + 1) * (height / (rows + 1));
            canvas.drawRect(
              Rect.fromLTWH(x - width * 0.1, balconyY, width * 0.1, height * 0.05),
              balconyPaint,
            );
          }
        }
        break;
        
      default: // store
        // Add storefront sign
        final signPaint = Paint()
          ..color = Colors.white.withOpacity(0.8);
          
        canvas.drawRect(
          Rect.fromLTWH(x + width * 0.2, y - height * 0.9, width * 0.6, height * 0.1),
          signPaint,
        );
    }
  }
  
  // Add atmospheric effects like fog, clouds or lighting
  void _addAtmosphericEffects(Canvas canvas, Size size) {
    if (lightingFactor > 0.7) {
      // Add sun rays when lighting is bright
      final rayPaint = Paint()
        ..color = Colors.white.withOpacity(0.03 * tiltFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
        
      for (int i = 0; i < 5; i++) {
        final startX = _random.nextDouble() * size.width;
        final endX = startX + (_random.nextDouble() - 0.5) * 300;
        
        canvas.drawLine(
          Offset(startX, 0),
          Offset(endX, size.height * 0.6),
          rayPaint,
        );
      }
    } else if (lightingFactor < 0.3) {
      // Add fog or mist when lighting is dim
      final fogPaint = Paint()
        ..color = Colors.white.withOpacity(0.02 * tiltFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
        
      for (int i = 0; i < 3; i++) {
        final y = size.height * (0.5 + (i * 0.15));
        final height = size.height * 0.1;
        
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, height),
          fogPaint,
        );
      }
    }
  }
  
  // Adjust color based on lighting factor
  Color _adjustColorWithLighting(Color baseColor) {
    // Calculate new RGB values considering lighting
    final r = baseColor.red + ((255 - baseColor.red) * lightingFactor * 0.3).toInt();
    final g = baseColor.green + ((255 - baseColor.green) * lightingFactor * 0.3).toInt();
    final b = baseColor.blue + ((255 - baseColor.blue) * lightingFactor * 0.3).toInt();
    
    return Color.fromRGBO(
      math.min(r, 255),
      math.min(g, 255),
      math.min(b, 255),
      baseColor.opacity,
    );
  }
  
  @override
  bool shouldRepaint(Enhanced3DBuildingsPainter oldDelegate) {
    return oldDelegate.detailLevel != detailLevel ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.topColor != topColor ||
           oldDelegate.tiltFactor != tiltFactor ||
           oldDelegate.lightingFactor != lightingFactor;
  }
} 