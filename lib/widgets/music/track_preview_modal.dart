import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/themes.dart';
import '../animations/pulse_animation.dart';
import '../common/shimmer_loading.dart';
import '../buttons/secondary_button.dart';

class TrackPreviewModal extends StatefulWidget {
  final Map<String, dynamic> pin;
  final bool isCollected;
  final VoidCallback? onClose;
  final VoidCallback? onCollect;
  final VoidCallback? onShare;
  
  const TrackPreviewModal({
    Key? key,
    required this.pin,
    this.isCollected = false,
    this.onClose,
    this.onCollect,
    this.onShare,
  }) : super(key: key);

  @override
  State<TrackPreviewModal> createState() => _TrackPreviewModalState();
}

class _TrackPreviewModalState extends State<TrackPreviewModal> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  late AnimationController _animationController;
  bool _showFullDetails = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Simulate loading the track preview
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    // Simulate track progress
    _startProgressSimulation();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      
      if (_isPlaying) {
        _startProgressSimulation();
        HapticFeedback.mediumImpact();
      }
    });
  }
  
  void _startProgressSimulation() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isPlaying) {
        setState(() {
          _progress += 0.01;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
          }
        });
        
        if (_isPlaying) {
          _startProgressSimulation();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 500) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: _showFullDetails 
            ? MediaQuery.of(context).size.height * 0.85
            : MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Main content with expanded album art
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Album art
                    Hero(
                      tag: 'album_art_${widget.pin['id']}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        height: MediaQuery.of(context).size.width - 48,
                        width: MediaQuery.of(context).size.width - 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isLoading
                              ? const ShimmerLoading(
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Album art
                                    CachedNetworkImage(
                                      imageUrl: widget.pin['albumArtUrl'] ?? 'https://via.placeholder.com/300',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const ShimmerLoading(
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.music_note, size: 80),
                                      ),
                                    ),
                                    
                                    // Play button overlay
                                    if (!_isLoading)
                                      AnimatedOpacity(
                                        opacity: 0.8,
                                        duration: const Duration(milliseconds: 200),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.3),
                                          child: Center(
                                            child: _isPlaying
                                                ? PulseAnimation(
                                                    maxScale: 1.1,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.pause,
                                                        size: 40,
                                                        color: AppTheme.accentColor,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.play_arrow,
                                                      size: 40,
                                                      color: AppTheme.accentColor,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    
                    // Track progress indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Track progress bar
                          LinearProgressIndicator(
                            value: _isLoading ? null : _progress,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentColor,
                            ),
                          ),
                          
                          // Track time indicators
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_progress * 30),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  '0:30',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Track info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Track title
                          Text(
                            widget.pin['title'] ?? 'Unknown Track',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          // Artist name
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              widget.pin['artist'] ?? 'Unknown Artist',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                          
                          // Pin details
                          if (_showFullDetails) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Pin Details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            
                            // Pin description
                            Text(
                              widget.pin['description'] ?? 'No description provided.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            
                            // Pin metadata
                            const SizedBox(height: 16),
                            _buildPinMetadata(
                              'Dropped by', 
                              widget.pin['username'] ?? 'Anonymous',
                            ),
                            _buildPinMetadata(
                              'Dropped on', 
                              widget.pin['dateCreated'] ?? 'Unknown date',
                            ),
                            _buildPinMetadata(
                              'Collected', 
                              widget.pin['collectionCount']?.toString() ?? '0',
                              suffix: ' times',
                            ),
                            
                            // Pin location
                            const SizedBox(height: 16),
                            Text(
                              'Location',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.pin['locationName'] ?? 'Unknown location',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Control buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Collect button
                      _buildActionButton(
                        icon: widget.isCollected ? Icons.playlist_add_check : Icons.playlist_add,
                        label: widget.isCollected ? 'Collected' : 'Collect',
                        onTap: widget.onCollect,
                        isActive: widget.isCollected,
                      ),
                      
                      // Play button (bigger)
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      
                      // Share button
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: widget.onShare,
                      ),
                    ],
                  ),
                  
                  // Toggle details button
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SecondaryButton(
                      text: _showFullDetails ? 'Show Less' : 'Show More',
                      onPressed: () {
                        setState(() {
                          _showFullDetails = !_showFullDetails;
                        });
                      },
                      icon: _showFullDetails 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive 
                    ? AppTheme.primaryColor
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive 
                  ? AppTheme.primaryColor
                  : Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive 
                  ? AppTheme.primaryColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPinMetadata(String label, String value, {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value + suffix,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(double seconds) {
    final int wholeSeconds = seconds.floor();
    final int minutes = wholeSeconds ~/ 60;
    final int remainingSeconds = wholeSeconds % 60;
    
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 