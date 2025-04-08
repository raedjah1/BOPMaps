import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pin.dart';
import '../../providers/map_provider.dart';
import '../../providers/music_provider.dart';
import '../../config/themes.dart';
import '../../widgets/music/track_preview_modal.dart';

class PinDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> pin;
  
  const PinDetailsScreen({
    Key? key,
    required this.pin,
  }) : super(key: key);

  @override
  State<PinDetailsScreen> createState() => _PinDetailsScreenState();
}

class _PinDetailsScreenState extends State<PinDetailsScreen> {
  bool _isPlayingPreview = false;
  bool _isCollecting = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            color: Colors.white,
            onPressed: _sharePin,
          ),
        ],
      ),
      body: Column(
        children: [
          // Album art cover image
          _buildCoverImage(),
          
          // Pin details
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Track title and artist
                  Text(
                    widget.pin['title'] ?? 'Unknown Track',
                    style: Theme.of(context).textTheme.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.pin['artist'] ?? 'Unknown Artist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Pin metadata
                  _buildMetadataRow(),
                  
                  const SizedBox(height: 24),
                  
                  // Pin description
                  if (widget.pin['description'] != null &&
                      widget.pin['description'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.pin['description'],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  
                  // Map location preview
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.map,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCoverImage() {
    final hasAlbumArt = widget.pin['albumArtUrl'] != null &&
                    widget.pin['albumArtUrl'].toString().isNotEmpty;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Album art or placeholder
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: hasAlbumArt
                ? DecorationImage(
                    image: NetworkImage(widget.pin['albumArtUrl']),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasAlbumArt
              ? const Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.grey,
                )
              : null,
        ),
        
        // Dark overlay
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        
        // Play preview button
        IconButton(
          icon: Icon(_isPlayingPreview ? Icons.pause_circle : Icons.play_circle),
          iconSize: 72,
          color: Colors.white,
          onPressed: _togglePreview,
        ),
      ],
    );
  }
  
  Widget _buildMetadataRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetadataItem(
          icon: Icons.calendar_today,
          label: 'Dropped',
          value: _formatDate(widget.pin['dateCreated']),
        ),
        _buildMetadataItem(
          icon: Icons.person_outline,
          label: 'By',
          value: widget.pin['username'] ?? 'Anonymous',
        ),
        _buildMetadataItem(
          icon: Icons.people_outline,
          label: 'Collected',
          value: '${widget.pin['collectionCount'] ?? 0}',
        ),
      ],
    );
  }
  
  Widget _buildMetadataItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    final isCollected = widget.pin['isCollected'] ?? false;
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(isCollected ? Icons.check : Icons.add),
            label: Text(isCollected ? 'Collected' : 'Collect'),
            style: ElevatedButton.styleFrom(
              foregroundColor: isCollected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onPrimary,
              backgroundColor: isCollected
                  ? Colors.grey[400]
                  : Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: isCollected ? null : _collectPin,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Listen'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 20,
            ),
          ),
          onPressed: _openMusicPlayer,
        ),
      ],
    );
  }
  
  void _togglePreview() {
    setState(() {
      _isPlayingPreview = !_isPlayingPreview;
    });
    
    // In a real app, this would play/pause the preview audio
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPlayingPreview ? 'Playing preview...' : 'Preview stopped'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _collectPin() {
    setState(() {
      _isCollecting = true;
    });
    
    // Simulate collecting the pin
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isCollecting = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin collected successfully!')),
        );
        
        // Close the screen
        Navigator.pop(context, {'collected': true});
      }
    });
  }
  
  void _sharePin() {
    // Show a snackbar indicating this would share the pin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing functionality coming soon!')),
    );
  }
  
  void _openMusicPlayer() {
    // Navigate to the music player screen
    Navigator.pushNamed(
      context,
      '/player',
      arguments: {'track': widget.pin},
    );
  }
  
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
} 