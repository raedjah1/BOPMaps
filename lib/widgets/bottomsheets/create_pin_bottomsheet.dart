import 'package:flutter/material.dart';
import '../../config/themes.dart';
import '../../utils/app_strings.dart';
import '../buttons/primary_button.dart';
import '../common/localized_text.dart';

class CreatePinBottomsheet extends StatelessWidget {
  final VoidCallback onCreateRegular;
  final VoidCallback onCreateCustom;
  final VoidCallback onCreatePlaylist;
  final VoidCallback? onClose;
  
  const CreatePinBottomsheet({
    Key? key,
    required this.onCreateRegular,
    required this.onCreateCustom,
    required this.onCreatePlaylist,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and Drag Handle
          Center(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                LocalizedText(
                  AppStrings.dropPin,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Regular Music Pin Option
          _buildOptionButton(
            context,
            icon: Icons.music_note,
            title: 'Single Track Pin',
            description: 'Share a single song at this location',
            onTap: onCreateRegular,
            color: AppTheme.accentColor,
          ),
          const SizedBox(height: 16),
          
          // Custom Pin Option
          _buildOptionButton(
            context,
            icon: Icons.palette,
            title: 'Custom Music Pin',
            description: 'Create a pin with custom styling and effects',
            onTap: onCreateCustom,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          
          // Playlist Pin Option
          _buildOptionButton(
            context,
            icon: Icons.queue_music,
            title: 'Playlist Pin',
            description: 'Share a playlist of songs at this location',
            onTap: onCreatePlaylist,
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 24),
          
          // Cancel Button
          TextButton(
            onPressed: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: LocalizedText(
              AppStrings.cancel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Extra space for bottom padding on smaller devices
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 