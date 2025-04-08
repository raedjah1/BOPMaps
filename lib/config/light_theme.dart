import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'text_theme.dart';
import 'theme_constants.dart';

/// The light theme for BOPMaps
ThemeData createLightTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    primaryColor: primaryColorLight,
    scaffoldBackgroundColor: backgroundColorLight,
    
    colorScheme: ColorScheme.light(
      primary: primaryColorLight,
      secondary: secondaryColorLight,
      tertiary: accentColorLight,
      surface: surfaceColorLight,
      background: backgroundColorLight,
      error: errorColorLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      onBackground: Colors.black87,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    
    // AppBar theme
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColorLight,
      foregroundColor: Colors.black87,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(
        color: Colors.black87,
        size: 24,
      ),
      actionsIconTheme: const IconThemeData(
        color: primaryColorLight,
        size: 24,
      ),
      titleTextStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Text theme
    textTheme: createTextTheme(base.textTheme),
    
    // Elevated Button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColorLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 1,
      ),
    ),
    
    // Outlined Button theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColorLight,
        side: const BorderSide(color: primaryColorLight),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Text Button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColorLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColorLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColorLight, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColorLight, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(
        color: Colors.grey[500],
        fontSize: 14,
      ),
      errorStyle: const TextStyle(
        color: errorColorLight,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Bottom Navigation Bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColorLight,
      selectedItemColor: primaryColorLight,
      unselectedItemColor: Colors.black54,
      elevation: 8,
    ),
    
    // Card theme
    cardTheme: CardTheme(
      color: surfaceColorLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    
    // Floating Action Button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFF80AB),
      foregroundColor: Colors.white,
      elevation: 4,
      splashColor: primaryColorLight,
    ),
    
    // Bottom Sheet theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceColorLight,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    
    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: surfaceColorLight,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Snackbar theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceColorLight,
      contentTextStyle: const TextStyle(color: Colors.black87),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 4,
    ),
  );
} 