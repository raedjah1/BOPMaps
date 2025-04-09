import 'package:flutter/material.dart';
import '../../config/constants.dart';

class MapPinWidget extends StatelessWidget {
  final Map<String, dynamic> pinData;
  
  const MapPinWidget({
    Key? key,
    required this.pinData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get pin color based on rarity
    final Color pinColor = _getPinColor();
    
    // Build a compact, guaranteed-to-fit map pin
    // Using CustomPaint to have precise control over rendering
    return SizedBox(
      width: 40.0,
      height: 40.0,
      child: CustomPaint(
        painter: MapPinPainter(
          pinColor: pinColor,
          rarity: pinData['rarity']?.toLowerCase() ?? 'common',
        ),
      ),
    );
  }
  
  // Get pin color based on rarity
  Color _getPinColor() {
    final String rarity = pinData['rarity']?.toLowerCase() ?? 'common';
    
    switch (rarity) {
      case 'common':
        return Colors.blue;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.purple;
      case 'epic':
        return Colors.amber;
      case 'legendary':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

/// Custom painter that draws a pin with guaranteed fitting
class MapPinPainter extends CustomPainter {
  final Color pinColor;
  final String rarity;
  
  MapPinPainter({
    required this.pinColor,
    required this.rarity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Size calculations - all proportional to the container size
    final double pinHeadRadius = size.width * 0.3;
    final double pinShaftWidth = size.width * 0.05;
    final double pinShaftHeight = size.height * 0.25;
    
    // Calculate center points
    final double centerX = size.width / 2;
    final double pinHeadCenterY = size.height * 0.25;
    
    // Create paths for each component
    
    // Pin head (circle)
    final headPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;
    
    // Draw shadow for 3D effect - but small enough to fit
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(
      Offset(centerX + 1, pinHeadCenterY + 1), 
      pinHeadRadius, 
      shadowPaint,
    );
    
    // Add a gradient for better 2.5D effect
    final headRect = Rect.fromCircle(
      center: Offset(centerX, pinHeadCenterY),
      radius: pinHeadRadius,
    );
    
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          pinColor.withOpacity(1.0),
          pinColor.withOpacity(0.7),
        ],
        stops: const [0.4, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(headRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(centerX, pinHeadCenterY), 
      pinHeadRadius, 
      gradientPaint,
    );
    
    // Add shine for 3D effect
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawCircle(
      Offset(centerX - pinHeadRadius * 0.3, pinHeadCenterY - pinHeadRadius * 0.3),
      pinHeadRadius * 0.3,
      shinePaint,
    );
    
    // Pin shaft
    final shaftPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;
    
    final shaftRect = Rect.fromLTWH(
      centerX - pinShaftWidth / 2,
      pinHeadCenterY + pinHeadRadius - pinShaftWidth / 2,
      pinShaftWidth,
      pinShaftHeight,
    );
    
    canvas.drawRect(shaftRect, shaftPaint);
    
    // Pin base/shadow dot
    final basePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, pinHeadCenterY + pinHeadRadius + pinShaftHeight),
        width: pinShaftWidth * 2.5,
        height: pinShaftWidth * 1.2,
      ),
      basePaint,
    );
    
    // Draw music note icon in the center
    _drawMusicIcon(canvas, Offset(centerX, pinHeadCenterY), pinHeadRadius * 0.6);
    
    // Add a subtle glow for rare+ items
    if (rarity != 'common') {
      final glowPaint = Paint()
        ..color = pinColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
      canvas.drawCircle(
        Offset(centerX, pinHeadCenterY),
        pinHeadRadius * 1.2,
        glowPaint,
      );
    }
  }
  
  // Draw a simple music note icon
  void _drawMusicIcon(Canvas canvas, Offset center, double size) {
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = size * 0.15
      ..strokeCap = StrokeCap.round;
    
    // Draw a simplified music note
    final noteHeadCenter = Offset(
      center.dx - size * 0.15,
      center.dy + size * 0.25,
    );
    
    // Note head
    canvas.drawCircle(noteHeadCenter, size * 0.25, iconPaint);
    
    // Note stem
    canvas.drawLine(
      Offset(noteHeadCenter.dx + size * 0.2, noteHeadCenter.dy - size * 0.1),
      Offset(noteHeadCenter.dx + size * 0.2, center.dy - size * 0.4),
      iconPaint,
    );
    
    // Note flag
    final flagPath = Path()
      ..moveTo(noteHeadCenter.dx + size * 0.2, center.dy - size * 0.4)
      ..quadraticBezierTo(
         noteHeadCenter.dx + size * 0.6,
         center.dy - size * 0.3,
         noteHeadCenter.dx + size * 0.4,
         center.dy - size * 0.1,
      );
    
    canvas.drawPath(flagPath, iconPaint);
  }
  
  @override
  bool shouldRepaint(MapPinPainter oldDelegate) {
    return oldDelegate.pinColor != pinColor || oldDelegate.rarity != rarity;
  }
} 