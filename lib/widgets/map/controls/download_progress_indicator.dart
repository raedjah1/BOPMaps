import 'package:flutter/material.dart';
import '../../../config/map_styles.dart';

/// Widget that shows the progress of downloading map data for offline use
class DownloadProgressIndicator extends StatelessWidget {
  final bool isDownloading;
  final double downloadProgress;

  const DownloadProgressIndicator({
    Key? key,
    required this.isDownloading,
    required this.downloadProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isDownloading) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Downloading map data...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: downloadProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  MapStyles.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(downloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 