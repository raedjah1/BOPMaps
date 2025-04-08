import 'package:flutter/material.dart';
import 'light_theme.dart';
import 'dark_theme.dart';
import 'theme_constants.dart';

/// Main theme class for BOPMaps
class AppTheme {
  // Light theme instance
  static final ThemeData lightTheme = createLightTheme();
  
  // Dark theme instance
  static final ThemeData darkTheme = createDarkTheme();
  
  // Common colors for direct access
  static const Color primaryColor = primaryColorLight;
  static const Color secondaryColor = secondaryColorLight;
  static const Color accentColor = Color(0xFFFF80AB);
  static const Color errorColor = errorColorLight;
  
  // Pin colors
  static const Color musicPinColor = Color(0xFFFF80AB);
  static const Color friendPinColor = Color(0xFFFF9FBC);
  static const Color collectedPinColor = Color(0xFF34D399);
  
  // Helper method to get current theme based on brightness
  static ThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.light ? lightTheme : darkTheme;
  }

  // App color palette
  static const Color popColor = Color(0xFFE91E63); // Pink
  static const Color rockColor = Color(0xFFE53935); // Red
  static const Color hiphopColor = Color(0xFF43A047); // Green
  static const Color electronicColor = Color(0xFF039BE5); // Blue
  static const Color jazzColor = Color(0xFFFFB74D); // Orange
  
  // Pin rarity colors
  static const Color commonColor = Color(0xFFBDBDBD); // Gray
  static const Color uncommonColor = Color(0xFF4CAF50); // Green
  static const Color rareColor = Color(0xFF2196F3); // Blue
  static const Color epicColor = Color(0xFF9C27B0); // Purple
  static const Color legendaryColor = Color(0xFFFF9800); // Orange
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightCardColor = Colors.white;
  static const Color lightTextColor = Color(0xFF212121);
  static const Color lightSecondaryTextColor = Color(0xFF757575);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFEEEEEE);
  static const Color darkSecondaryTextColor = Color(0xFFB0B0B0);
  
  // Aura effect colors
  static const Color auraColor = primaryColor;

  // Get color for pin based on rarity
  static Color getPinColorForRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return commonColor;
      case 'uncommon':
        return uncommonColor;
      case 'rare':
        return rareColor;
      case 'epic':
        return epicColor;
      case 'legendary':
        return legendaryColor;
      default:
        return commonColor;
    }
  }
  
  // Get color for music genre
  static Color getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'pop':
        return popColor;
      case 'rock':
        return rockColor;
      case 'hip hop':
      case 'hiphop':
      case 'rap':
        return hiphopColor;
      case 'electronic':
      case 'edm':
      case 'dance':
        return electronicColor;
      case 'jazz':
      case 'blues':
        return jazzColor;
      default:
        return primaryColor;
    }
  }
} 