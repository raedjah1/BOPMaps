import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/themes.dart';
import '../../widgets/music/track_selector.dart';
import '../../widgets/animations/fade_in_animation.dart';

class TrackSelectScreen extends StatelessWidget {
  const TrackSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Select a Track'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh tracks
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing tracks...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Spotify connection status
          _buildSpotifyConnectionStatus(),
          
          // Track selector
          Expanded(
            child: TrackSelector(
              onTrackSelected: (track) {
                // Provide haptic feedback
                HapticFeedback.mediumImpact();
                
                // Return selected track to previous screen
                Navigator.pop(context, {'track': track});
              },
            ),
          ),
        ],
      ),
      bottomSheet: _buildConnectBar(context),
    );
  }
  
  Widget _buildSpotifyConnectionStatus() {
    return FadeInAnimation(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.accentColor.withOpacity(0.1),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppTheme.accentColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Connected to Spotify',
              style: TextStyle(
                color: AppTheme.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              'Recently played',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectBar(BuildContext context) {
    return FadeInAnimation(
      delay: const Duration(milliseconds: 300),
      offset: const Offset(0, 0.5),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Spotify button
            Expanded(
              child: OutlinedButton.icon(
                icon: Image.network(
                  'https://storage.googleapis.com/pr-newsroom-wp/1/2018/11/Spotify_Logo_RGB_Green.png',
                  height: 18,
                ),
                label: const Text('Connect Spotify'),
                onPressed: () {
                  // Handle Spotify connection
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Apple Music button
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.music_note),
                label: const Text('Apple Music'),
                onPressed: () {
                  // Handle Apple Music connection
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 