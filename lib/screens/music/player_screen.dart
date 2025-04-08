import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../config/themes.dart';
import 'dart:ui';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> track;
  
  const PlayerScreen({
    Key? key,
    required this.track,
  }) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isPlaying = false;
  double _currentSliderValue = 0.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    // Start playing automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isPlaying = true;
      });
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Album Art
                  _buildAlbumArt(),
                  
                  const Spacer(),
                  
                  // Track Info
                  Text(
                    widget.track['title'] ?? 'Unknown Track',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.track['artist'] ?? 'Unknown Artist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Progress bar
                  _buildProgressBar(),
                  
                  const SizedBox(height: 32),
                  
                  // Controls
                  _buildControls(),
                  
                  const Spacer(),
                  
                  // Additional info and actions
                  _buildBottomActions(),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlbumArt() {
    final hasAlbumArt = widget.track['albumArtUrl'] != null &&
                    widget.track['albumArtUrl'].toString().isNotEmpty;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (_, child) {
        return Transform.rotate(
          angle: _isPlaying ? _animationController.value * 2 * 3.14159 : 0,
          child: child,
        );
      },
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
          image: hasAlbumArt
              ? DecorationImage(
                  image: NetworkImage(widget.track['albumArtUrl']),
                  fit: BoxFit.cover,
                )
              : null,
          color: hasAlbumArt ? null : Colors.grey[300],
        ),
        child: !hasAlbumArt
            ? const Icon(
                Icons.music_note,
                size: 100,
                color: Colors.grey,
              )
            : null,
      ),
    );
  }
  
  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            trackHeight: 2.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          ),
          child: Slider(
            value: _currentSliderValue,
            onChanged: (value) {
              setState(() {
                _currentSliderValue = value;
              });
            },
            min: 0.0,
            max: 1.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(seconds: (_currentSliderValue * 180).round())),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(const Duration(minutes: 3)),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
          onPressed: () {
            // Previous track functionality
          },
        ),
        const SizedBox(width: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            onPressed: _togglePlayPause,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
          onPressed: () {
            // Next track functionality
          },
        ),
      ],
    );
  }
  
  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.shuffle, 'Shuffle'),
        _buildActionButton(Icons.repeat, 'Repeat'),
        _buildActionButton(Icons.playlist_add, 'Add to Playlist'),
        _buildActionButton(Icons.share, 'Share'),
      ],
    );
  }
  
  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white.withOpacity(0.8)),
          onPressed: () {
            // Action functionality
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label feature coming soon!')),
            );
          },
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      
      if (_isPlaying) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    });
  }
  
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_to_queue),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to queue')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Save to Playlist'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Save to playlist coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.album),
              title: const Text('View Album'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View album coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Artist'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View artist coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
} 