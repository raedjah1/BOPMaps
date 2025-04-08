import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/themes.dart';
import '../animations/pulse_animation.dart';
import '../common/shimmer_loading.dart';

class TrackCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? albumArt;
  final String? duration;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final bool isSelected;
  final bool isCollected;
  final bool showPlayButton;
  final EdgeInsets? margin;
  final double? height;
  final double? width;
  
  const TrackCard({
    Key? key,
    required this.title,
    required this.artist,
    this.albumArt,
    this.duration,
    this.onTap,
    this.onPlay,
    this.isPlaying = false,
    this.isSelected = false,
    this.isCollected = false,
    this.showPlayButton = true,
    this.margin,
    this.height,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // Album art with gradient overlay
              _buildAlbumArt(),
              
              // Track details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Artist
                      Text(
                        artist,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Duration
                      if (duration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            duration!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Play button or status indicator
              if (showPlayButton)
                _buildPlayButton(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlbumArt() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Album art or placeholder
          albumArt != null
              ? Hero(
                  tag: 'album_art_$title',
                  child: CachedNetworkImage(
                    imageUrl: albumArt!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ShimmerLoading(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.music_note),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.music_note),
                ),
          
          // Collected badge
          if (isCollected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.collectedPinColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlayButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: isPlaying
          ? PulseAnimation(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          : GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
    );
  }
} 