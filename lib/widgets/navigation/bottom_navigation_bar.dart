import 'dart:ui';
import 'package:flutter/material.dart';

class MusicPinBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final VoidCallback? onAddPinPressed;

  const MusicPinBottomNavBar({
    Key? key, 
    required this.currentIndex,
    required this.onTabSelected,
    this.onAddPinPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Modern gradient background colors
    final gradientStart = HSLColor.fromColor(theme.colorScheme.primary).withLightness(0.2).toColor();
    final gradientEnd = HSLColor.fromColor(theme.colorScheme.secondary).withLightness(0.15).toColor();

    return Container(
      height: 76 + bottomPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart.withOpacity(0.92),
            gradientEnd.withOpacity(0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, -3),
            spreadRadius: 1,
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: 'Explore',
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    icon: Icons.library_music_outlined,
                    activeIcon: Icons.library_music,
                    label: 'Collection',
                  ),
                  _buildAddPinButton(context),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Friends',
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;
    
    // Modern glowing color for active items
    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withOpacity(0.6);

    return InkWell(
      onTap: () => onTabSelected(index),
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack for glow effect on active icons
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect for active icon
                if (isSelected)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                // Using AnimatedSwitcher for smooth icon transition
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey<bool>(isSelected),
                    color: isSelected ? activeColor : inactiveColor,
                    size: isSelected ? 28 : 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Text with animated size and opacity
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: isSelected ? 14 : 12,
              ),
              child: Text(label),
            ),
            // Animated indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPinButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elevated container with modern gradient and glow effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.9),
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 0,
                  offset: const Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddPinPressed,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.add_location_alt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Label with shimmer effect
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white,
                  Colors.white.withOpacity(0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: const Text(
              'Add Pin',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Create a basic music pin-themed indicator widget
class MusicPinIndicator extends StatelessWidget {
  final bool isActive;
  final Color color;
  
  const MusicPinIndicator({
    Key? key,
    required this.isActive,
    required this.color,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 16 : 0,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
} 