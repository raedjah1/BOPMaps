import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/themes.dart';
import '../../widgets/music/track_selector.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../services/api/django_auth_service.dart';
import 'package:provider/provider.dart';
import '../../services/music/spotify_service.dart';

class TrackSelectScreen extends StatefulWidget {
  const TrackSelectScreen({Key? key}) : super(key: key);

  @override
  State<TrackSelectScreen> createState() => _TrackSelectScreenState();
}

class _TrackSelectScreenState extends State<TrackSelectScreen> {
  bool isSpotifyConnected = false;
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkSpotifyConnection();
  }
  
  Future<void> _checkSpotifyConnection() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final djangoAuthService = DjangoAuthService();
      final musicServices = await djangoAuthService.getConnectedMusicServices();
      
      setState(() {
        isSpotifyConnected = musicServices.contains('spotify');
        isLoading = false;
      });
    } catch (e) {
      print('Error checking Spotify connection: $e');
      setState(() {
        isSpotifyConnected = false;
        isLoading = false;
      });
    }
  }

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
              // Refresh tracks and connection status
              _checkSpotifyConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing...'),
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
    if (isLoading) {
      return FadeInAnimation(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[200],
          child: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Checking connection status...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (!isSpotifyConnected) {
      return FadeInAnimation(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[200],
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.grey[700],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Connect to Spotify to view your tracks',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
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
              child: isSpotifyConnected
                ? OutlinedButton.icon(
                    icon: Image.network(
                      'https://storage.googleapis.com/pr-newsroom-wp/1/2018/11/Spotify_Logo_RGB_Green.png',
                      height: 18,
                    ),
                    label: const Text('Disconnect'),
                    onPressed: () async {
                      try {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Disconnecting from Spotify...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        
                        // Use SpotifyService to disconnect
                        final spotifyService = SpotifyService();
                        final djangoAuthService = DjangoAuthService();
                        
                        // Disconnect from both services
                        final spotifySuccess = await spotifyService.disconnect();
                        await djangoAuthService.logout(); // Also clear Django tokens
                        
                        if (spotifySuccess) {
                          setState(() {
                            isSpotifyConnected = false;
                          });
                          
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Disconnected from Spotify'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          throw Exception('Failed to disconnect from Spotify');
                        }
                      } catch (e) {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error disconnecting from Spotify: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      foregroundColor: Colors.red,
                    ),
                  )
                : OutlinedButton.icon(
                    icon: Image.network(
                      'https://storage.googleapis.com/pr-newsroom-wp/1/2018/11/Spotify_Logo_RGB_Green.png',
                      height: 18,
                    ),
                    label: const Text('Connect Spotify'),
                    onPressed: () async {
                      try {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connecting to Spotify...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        
                        // Use DjangoAuthService to connect to Spotify
                        final djangoAuthService = DjangoAuthService();
                        final success = await djangoAuthService.authenticateWithSpotify();
                        
                        if (success) {
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Successfully connected to Spotify'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          // Update connection status
                          _checkSpotifyConnection();
                        } else {
                          throw Exception('Authentication failed');
                        }
                      } catch (e) {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error connecting to Spotify: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
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