import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/themes.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;
  final Widget? child;
  
  const ShimmerLoading({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Define shimmer colors based on theme
    final base = baseColor ?? 
        (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!);
    final highlight = highlightColor ?? 
        (isDarkMode ? Colors.grey[700]! : Colors.grey[100]!);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: duration,
      child: child ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Convenience class for Track Card shimmer
class TrackCardShimmer extends StatelessWidget {
  final EdgeInsets? margin;
  
  const TrackCardShimmer({
    Key? key,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album art placeholder
          const ShimmerLoading(
            width: 80,
            height: 80,
            borderRadius: 0,
          ),
          
          // Track details placeholder
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title placeholder
                  const ShimmerLoading(
                    width: double.infinity,
                    height: 16,
                  ),
                  const SizedBox(height: 8),
                  
                  // Artist placeholder
                  ShimmerLoading(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: 14,
                  ),
                ],
              ),
            ),
          ),
          
          // Play button placeholder
          const Padding(
            padding: EdgeInsets.all(16),
            child: ShimmerLoading(
              width: 36,
              height: 36,
              borderRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience class for Pin shimmer
class PinShimmer extends StatelessWidget {
  final double size;
  
  const PinShimmer({
    Key? key,
    this.size = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }
} 