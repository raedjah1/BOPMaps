import 'package:flutter/material.dart';

/// Class that provides a catalog of all map control buttons for reference
class MapControlsCatalog {
  /// Get a count of all map control buttons
  static Map<String, int> getControlsCount() {
    return {
      // Main zoom controls (from MapZoomControls)
      'Tilt/3D Toggle Button': 1,
      'Zoom In Button': 1,
      'Zoom Out Button': 1,
      'Location Tracking Button': 1,
      'Download Offline Button': 1,
      
      // Navigation controls (from MapNavigationControls)
      'Current Location Button': 1,
      'Compass Reset Button': 1,
      
      // Zoom level navigator buttons (from ZoomLevelNavigator)
      'Zoom Level Buttons': 5, // Levels 1-5
      
      // Map type selector (from MapScreen)
      'Map Type Options': 3, // Standard, 2.5D, Leaflet
      
      // Total
      'Total Buttons': 15
    };
  }
  
  /// List all control widgets with descriptions
  static List<Map<String, String>> getControlsDescription() {
    return [
      {
        'name': 'MapZoomControls',
        'description': 'Controls for adjusting map zoom, tilt, and toggling location tracking',
        'buttons': '5 buttons (Tilt, Zoom In, Zoom Out, Location Tracking, Download)'
      },
      {
        'name': 'MapNavigationControls',
        'description': 'Controls for centering on user location and resetting map view',
        'buttons': '2 buttons (Current Location, Compass Reset)'
      },
      {
        'name': 'ZoomLevelNavigator',
        'description': 'Quick navigation between predefined zoom levels',
        'buttons': '5 buttons (Level 1-5)'
      },
      {
        'name': 'ZoomLevelInfoCard',
        'description': 'Information display about current zoom level',
        'buttons': '0 buttons (display only)'
      },
      {
        'name': 'DownloadProgressIndicator',
        'description': 'Shows progress when downloading map data for offline use',
        'buttons': '0 buttons (display only)'
      },
      {
        'name': 'StatusMessagesWidget',
        'description': 'Displays error messages and notifications',
        'buttons': '0 buttons (display only)'
      },
      {
        'name': 'Map Type Selector',
        'description': 'Options for different map view types',
        'buttons': '3 options (Standard, 2.5D, Leaflet)'
      }
    ];
  }
} 