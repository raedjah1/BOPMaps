import 'package:flutter/material.dart';

/// Global application state that doesn't fit neatly into provider models
/// Primarily for simple flags and values that affect multiple parts of the app
class AppState {
  // Flag for when user is currently in the collect pin flow
  static final ValueNotifier<bool> isCollectingPin = ValueNotifier<bool>(false);
  
  // Flag for when app should mute audio (e.g., entering background)
  static final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  
  // Flag for tracking if pin details are expanded
  static final ValueNotifier<bool> isPinDetailsExpanded = ValueNotifier<bool>(false);
  
  // Flag for tracking if a pin is currently playing
  static final ValueNotifier<bool> isPinPlaying = ValueNotifier<bool>(false);
  
  // Currently active theme mode
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  
  // Last known position (for quick access without going through provider)
  static double? lastLatitude;
  static double? lastLongitude;
  
  // Reset all state (e.g., on logout)
  static void resetState() {
    isCollectingPin.value = false;
    isMuted.value = false;
    isPinDetailsExpanded.value = false;
    isPinPlaying.value = false;
    lastLatitude = null;
    lastLongitude = null;
  }
} 