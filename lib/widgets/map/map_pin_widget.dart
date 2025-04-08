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
    // Get pin size based on rarity
    final double pinSize = _getPinSize();
    
    // Get pin color based on rarity
    final Color pinColor = _getPinColor();
    
    // Build an attractive 2.5D pin with shadow and highlight effects
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin top with 3D effect
        Container(
          width: pinSize * 0.8,
          height: pinSize * 0.8,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            boxShadow: [
              // Add depth with shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
              // Add shine effect
              BoxShadow(
                color: Colors.white.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: -2,
                offset: const Offset(-2, -2),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                pinColor.withOpacity(1),
                pinColor.withOpacity(0.7),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              color: Colors.white,
              size: pinSize * 0.4,
            ),
          ),
        ),
        
        // Pin shaft
        Container(
          width: 2,
          height: pinSize * 0.5,
          decoration: BoxDecoration(
            color: pinColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        
        // Shadow dot at base
        Container(
          width: 6,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Get pin size based on rarity
  double _getPinSize() {
    final String rarity = pinData['rarity']?.toLowerCase() ?? 'common';
    return AppConstants.pinSizeByRarity[rarity] ?? 60.0;
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