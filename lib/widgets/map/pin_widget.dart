import 'package:flutter/material.dart';
import 'dart:async';
import '../../config/themes.dart';
import '../../models/pin.dart';

class MusicPinWidget extends StatefulWidget {
  final Pin pin;
  final VoidCallback onTap;
  final bool isWithinRange;
  
  const MusicPinWidget({
    Key? key,
    required this.pin,
    required this.onTap,
    required this.isWithinRange,
  }) : super(key: key);

  @override
  State<MusicPinWidget> createState() => _MusicPinWidgetState();
}

class _MusicPinWidgetState extends State<MusicPinWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Timer _pulseTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    
    // Create animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Create pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start periodic pulse effect
    _pulseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && widget.isWithinRange) {
        _animationController.forward().then((_) => _animationController.reverse());
      }
    });
    
    // Initial pulse
    if (widget.isWithinRange) {
      _animationController.forward().then((_) => _animationController.reverse());
    }
  }
  
  // Simulate playing state toggling for demo
  void _togglePlayState() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isPlaying) {
      // Start continuous pulsing when "playing"
      _animationController.repeat(reverse: true);
    } else {
      // Stop continuous pulsing
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.isWithinRange ? _togglePlayState : null,
      child: Column(
        children: [
          // Pin label/title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isWithinRange ? Colors.white : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.pin.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.isWithinRange ? AppTheme.primaryColor : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          
          // Pin icon with pulse animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isWithinRange ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base icon
                Icon(
                  Icons.location_on,
                  color: _getPinColor(),
                  size: 40,
                ),
                
                // Music icon overlay
                Positioned(
                  top: 8,
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.music_note,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                
                // Show pulse effect if playing
                if (_isPlaying)
                  Positioned(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentColor.withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Get pin color based on state
  Color _getPinColor() {
    if (!widget.isWithinRange) {
      return Colors.grey; // Out of range
    } else if (_isPlaying) {
      return AppTheme.accentColor; // Playing
    } else if (widget.pin.isCollected) {
      return Colors.green; // Collected
    } else {
      return AppTheme.primaryColor; // Default
    }
  }
  
  @override
  void dispose() {
    _pulseTimer.cancel();
    _animationController.dispose();
    super.dispose();
  }
} 