import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/map_provider.dart';

class TopNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSettingsTap;
  final bool showBackButton;
  final List<Widget>? actions;

  const TopNavigationBar({
    Key? key,
    required this.title,
    this.onSearchTap,
    this.onSettingsTap,
    this.showBackButton = false,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 2.0,
      centerTitle: true,
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
      actions: actions ?? _buildDefaultActions(context, theme),
    );
  }

  List<Widget> _buildDefaultActions(BuildContext context, ThemeData theme) {
    return [
      // Search button
      if (onSearchTap != null)
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchTap,
          tooltip: 'Search music pins',
        ),
      
      // Settings or more options
      if (onSettingsTap != null)
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: onSettingsTap,
          tooltip: 'Map settings',
        ),
      
      // Shows toggle button for map style if no custom actions provided
      if (actions == null)
        Consumer<MapProvider>(
          builder: (context, mapProvider, _) {
            return IconButton(
              icon: const Icon(Icons.layers),
              onPressed: () {
                // Show map style selection
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _buildMapStyleSelector(context),
                );
              },
              tooltip: 'Map style',
            );
          },
        ),
    ];
  }

  Widget _buildMapStyleSelector(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 16),
            ),
          ),
          const Text(
            'Map Style',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Map style options
          _buildStyleOption(
            context,
            title: 'Standard',
            description: 'Classic map view',
            icon: Icons.map,
            onTap: () {
              // Set standard map style
              Navigator.pop(context);
            },
          ),
          
          _buildStyleOption(
            context,
            title: '2.5D',
            description: 'Perspective view with buildings',
            icon: Icons.view_in_ar,
            isSelected: true,
            onTap: () {
              // Set 2.5D map style
              Navigator.pop(context);
            },
          ),
          
          _buildStyleOption(
            context,
            title: 'Satellite',
            description: 'Aerial imagery',
            icon: Icons.satellite,
            onTap: () {
              // Set satellite style
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStyleOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}