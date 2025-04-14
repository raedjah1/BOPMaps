import 'package:flutter/material.dart';
import '../../../config/map_styles.dart';

/// Widget that displays information about the current zoom level
class ZoomLevelInfoCard extends StatelessWidget {
  final int currentZoomLevel;
  
  const ZoomLevelInfoCard({
    Key? key,
    required this.currentZoomLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: AnimatedOpacity(
        opacity: currentZoomLevel == 0 ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getZoomLevelIcon(),
                color: MapStyles.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                _getZoomLevelName(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getZoomLevelIcon() {
    switch (currentZoomLevel) {
      case 1: return Icons.public;
      case 2: return Icons.map;
      case 3: return Icons.location_city;
      case 4: return Icons.location_on;
      case 5: return Icons.streetview;
      default: return Icons.help_outline;
    }
  }
  
  String _getZoomLevelName() {
    switch (currentZoomLevel) {
      case 1: return 'Global View';
      case 2: return 'Continental View';
      case 3: return 'Regional View';
      case 4: return 'Local Area View';
      case 5: return 'Street View';
      default: return 'Custom Zoom';
    }
  }
} 