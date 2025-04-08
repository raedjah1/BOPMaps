import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/themes.dart';

class ShimmerPinWidget extends StatelessWidget {
  final double size;
  
  const ShimmerPinWidget({
    Key? key, 
    this.size = 60.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pin circle
            Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            
            // Pin bottom triangle
            Positioned(
              bottom: 0,
              child: CustomPaint(
                size: Size(size * 0.3, size * 0.3),
                painter: _PinTrianglePainter(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the pin's bottom triangle
class _PinTrianglePainter extends CustomPainter {
  final Color color;
  
  _PinTrianglePainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 