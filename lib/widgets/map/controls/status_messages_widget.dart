import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/map_provider.dart';

/// Widget that displays status messages such as network errors - now disabled
class StatusMessagesWidget extends StatelessWidget {
  const StatusMessagesWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always return an empty widget to disable error messages
    return const SizedBox.shrink();
    
    // Original implementation is commented out below
    /*
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        if (mapProvider.hasNetworkError) {
          return Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mapProvider.errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
    */
  }
} 