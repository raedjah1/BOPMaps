import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/themes.dart';
import '../../models/pin.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/music_service.dart';

class PinDetailsSheet extends StatefulWidget {
  final Pin pin;
  
  const PinDetailsSheet({
    Key? key,
    required this.pin,
  }) : super(key: key);

  @override
  State<PinDetailsSheet> createState() => _PinDetailsSheetState();
}

class _PinDetailsSheetState extends State<PinDetailsSheet> {
  bool _isPlaying = false;
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, AuthProvider>(
      builder: (context, mapProvider, authProvider, child) {
        final bool isOwner = widget.pin.userId == authProvider.currentUser?.id;
        final bool canCollect = !isOwner && !widget.pin.isCollected && widget.pin.isWithinRange;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Header with title and actions
                        _buildHeader(isOwner, mapProvider),
                        const SizedBox(height: 16),
                        
                        // Music track card
                        _buildMusicTrackCard(),
                        const SizedBox(height: 24),
                        
                        // Description
                        if (widget.pin.description != null && widget.pin.description!.isNotEmpty)
                          _buildDescriptionSection(),
                        
                        // Pin metadata
                        _buildMetadataSection(),
                        const SizedBox(height: 16),
                        
                        // Action buttons
                        _buildActionButtons(canCollect, mapProvider),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Header with title and actions
  Widget _buildHeader(bool isOwner, MapProvider mapProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pin.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    widget.pin.isPrivate ? Icons.lock : Icons.public,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.pin.isPrivate ? 'Private pin' : 'Public pin',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Actions menu (if owner)
        if (isOwner)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                // TODO: Implement edit functionality
              } else if (value == 'delete') {
                _showDeleteConfirmation(context, mapProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit pin'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete pin', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  // Music track card with play controls
  Widget _buildMusicTrackCard() {
    final track = widget.pin.track;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Album art
          if (track.albumArtUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: Image.network(
                  track.albumArtUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note, size: 64),
                  ),
                ),
              ),
            ),
          
          // Track info and controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Service icon
                    _buildServiceIcon(track.serviceType),
                    const SizedBox(width: 8),
                    
                    // Track info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (track.album != null)
                            Text(
                              track.album!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Play controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!widget.pin.isWithinRange)
                      // Out of range message
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                            const SizedBox(width: 4),
                            Text(
                              'Get closer to play',
                              style: TextStyle(color: Colors.amber[800]),
                            ),
                          ],
                        ),
                      )
                    else
                      // Play/Pause button
                      ElevatedButton.icon(
                        onPressed: _togglePlayState,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Description section
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.pin.description != null && widget.pin.description!.length > 100)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(_isExpanded ? 'Show less' : 'Show more'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.pin.description!,
          style: const TextStyle(fontSize: 16),
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
  
  // Metadata section
  Widget _buildMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pin details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Created by
        _buildMetadataItem(
          icon: Icons.person,
          label: 'Created by',
          value: widget.pin.user?.username ?? 'Unknown user',
        ),
        
        // Dropped on (date)
        _buildMetadataItem(
          icon: Icons.calendar_today,
          label: 'Dropped on',
          value: _formatDate(widget.pin.createdAt),
        ),
        
        // Collection count
        _buildMetadataItem(
          icon: Icons.bookmark,
          label: 'Collected',
          value: '${widget.pin.collectionCount} times',
        ),
        
        // Distance
        _buildMetadataItem(
          icon: Icons.near_me,
          label: 'Distance',
          value: widget.pin.distance != null 
              ? '${(widget.pin.distance! / 1000).toStringAsFixed(2)} km away'
              : 'Unknown distance',
        ),
      ],
    );
  }
  
  // Metadata item
  Widget _buildMetadataItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Action buttons
  Widget _buildActionButtons(bool canCollect, MapProvider mapProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Like button
        _buildActionButton(
          icon: widget.pin.isLiked 
            ? Icons.favorite 
            : Icons.favorite_border,
          color: widget.pin.isLiked 
            ? Colors.red 
            : Colors.grey[700]!,
          label: 'Like',
          count: widget.pin.likeCount,
          onPressed: () {
            // Toggle like
            mapProvider.toggleLikePin(widget.pin.id);
          },
        ),
        
        // Collect button
        _buildActionButton(
          icon: widget.pin.isCollected 
            ? Icons.bookmark 
            : Icons.bookmark_border,
          color: widget.pin.isCollected 
            ? AppTheme.primaryColor 
            : Colors.grey[700]!,
          label: 'Collect',
          count: widget.pin.collectionCount,
          onPressed: canCollect 
            ? () => mapProvider.collectPin(widget.pin.id) 
            : null,
        ),
        
        // Share button
        _buildActionButton(
          icon: Icons.share,
          color: Colors.grey[700]!,
          label: 'Share',
          count: null,
          onPressed: () {
            // TODO: Implement share functionality
          },
        ),
      ],
    );
  }
  
  // Action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    int? count,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              count != null ? '$label ($count)' : label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Service icon
  Widget _buildServiceIcon(String serviceType) {
    IconData iconData;
    Color iconColor;
    
    switch (serviceType.toLowerCase()) {
      case 'spotify':
        iconData = Icons.music_note;
        iconColor = Colors.green;
        break;
      case 'apple_music':
        iconData = Icons.music_note;
        iconColor = Colors.red;
        break;
      case 'youtube_music':
        iconData = Icons.music_note;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.music_note;
        iconColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
  
  // Toggle play state
  void _togglePlayState() {
    if (!widget.pin.isWithinRange) {
      return;
    }
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    final MusicService musicService = MusicService();
    
    if (_isPlaying) {
      musicService.playTrack(
        trackId: widget.pin.track.id,
        serviceType: widget.pin.track.serviceType,
      );
    } else {
      musicService.pauseTrack();
    }
  }
  
  // Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(BuildContext context, MapProvider mapProvider) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pin?'),
        content: const Text(
          'This will permanently delete this pin. This action cannot be undone.'
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              final success = await mapProvider.deletePin(widget.pin.id);
              if (success) {
                Navigator.pop(context); // Close bottom sheet
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pin deleted successfully')),
                );
              } else {
                // Show error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete pin. Please try again.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
} 