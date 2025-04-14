import 'package:flutter/material.dart';

/// Map styling constants inspired by Uber's 2.5D map design
class MapStyles {
  // Base colors - enhanced for modern, sleek dark theme
  static const Color primaryColor = Color(0xFF1976D2);  // Change to match your theme
  static const Color backgroundColor = Color(0xFF121212);
  
  // Enhanced water colors with rich oceanic palette
  static const Color waterColor = Color(0xFF182834);      // Base water color
  static const Color oceanDeepColor = Color(0xFF0A3D62);  // Deep ocean (zoomed out)
  static const Color oceanShallowColor = Color(0xFF1E5D8C); // Shallow ocean
  static const Color riverColor = Color(0xFF2E86C1);      // Rivers
  static const Color lakeColor = Color(0xFF21618C);       // Lakes
  
  // Sea gradients for texture effects
  static const List<Color> oceanGradient = [
    Color(0xFF0A3D62),  // Deep blue
    Color(0xFF1A5276),  // Mid-deep blue
    Color(0xFF2874A6),  // Medium blue
    Color(0xFF3498DB),  // Lighter blue (shallow)
  ];
  
  // Improved land color with subtle warmth
  static const Color landColor = Color(0xFF202124);
  
  // Enhanced road colors with better contrast
  static const Color roadPrimaryColor = Color(0xFFF5F5F5);
  static const Color roadSecondaryColor = Color(0xFFD0D0D0);
  static const Color roadMinorColor = Color(0xFFAAAAAA);
  
  // Modern building colors with better 3D effect
  static const Color buildingBaseColor = Color(0xFF292929);
  static const Color buildingTopColor = Color(0xFF3D3D3D);
  static const Color buildingSideColor = Color(0xFF333333);
  
  // Improved natural features colors
  static const Color parksColor = Color(0xFF1E352C);
  static const Color forestColor = Color(0xFF203A2E);
  static const Color beachColor = Color(0xFF4E4B38);
  
  // New elements - POI categories
  static const Color entertainmentColor = Color(0xFF9C27B0);
  static const Color foodAndDrinkColor = Color(0xFFFF7043);
  static const Color retailColor = Color(0xFF5C6BC0);
  static const Color transportColor = Color(0xFF26A69A);
  static const Color landmarkColor = Color(0xFFFFB300);
  
  // Subtle highlight colors for special areas
  static const Color downtownAreaColor = Color(0xFF373739);
  static const Color commercialAreaColor = Color(0xFF303033);
  static const Color residentialAreaColor = Color(0xFF242527);
  
  // 2.5D effect settings
  static const double defaultTiltAngle = 0.35;  // In radians (about 20 degrees)
  static const double defaultRotationAngle = 0.0;
  static const double maxTiltAngle = 0.7;  // In radians (about 40 degrees)
  static const double buildingHeightScale = 0.85;  // Reduced from 1.0 for optimization
  static const double shadowOpacity = 0.3;  // Increased from 0.2 for better definition
  
  // Building simplification thresholds for optimization
  static const double simplifyBuildingsBeforeZoom = 14.0;  // Simplify buildings below this zoom level
  static const double simplifyBuildingsTolerance = 0.00005;  // Simplification tolerance
  static const int maxBuildingsPerTile = 100;  // Maximum buildings to render per tile at low zoom levels
  
  // Animation durations
  static const Duration tiltAnimationDuration = Duration(milliseconds: 500);
  static const Duration cameraMoveAnimationDuration = Duration(milliseconds: 400);
  static const Duration zoomAnimationDuration = Duration(milliseconds: 300);

  // Custom JSON styles for Leaflet/MapBox tiles implementation
  static String get leafletDarkStyle => '''
    {
      "version": 8,
      "name": "BOPMapsStyle",
      "metadata": {"maputnik:renderer": "mbgljs"},
      "sources": {
        "openmaptiles": {
          "type": "vector",
          "url": "https://api.maptiler.com/tiles/v3/tiles.json?key=YOUR_API_KEY"
        }
      },
      "layers": [
        {
          "id": "background",
          "type": "background",
          "paint": {"background-color": "${_colorToHex(backgroundColor)}"}
        },
        {
          "id": "ocean",
          "type": "fill",
          "source": "openmaptiles",
          "source-layer": "water",
          "filter": ["==", "class", "ocean"],
          "paint": {
            "fill-color": "${_colorToHex(oceanDeepColor)}",
            "fill-opacity": 0.95
          }
        },
        {
          "id": "water",
          "type": "fill",
          "source": "openmaptiles",
          "source-layer": "water",
          "paint": {"fill-color": "${_colorToHex(waterColor)}"}
        },
        {
          "id": "landuse_park",
          "type": "fill",
          "source": "openmaptiles",
          "source-layer": "landuse",
          "filter": ["==", "class", "park"],
          "paint": {"fill-color": "${_colorToHex(parksColor)}"}
        },
        {
          "id": "landuse_forest",
          "type": "fill",
          "source": "openmaptiles",
          "source-layer": "landuse",
          "filter": ["==", "class", "forest"],
          "paint": {"fill-color": "${_colorToHex(forestColor)}"}
        },
        {
          "id": "landuse_beach",
          "type": "fill",
          "source": "openmaptiles",
          "source-layer": "landuse",
          "filter": ["==", "class", "beach"],
          "paint": {"fill-color": "${_colorToHex(beachColor)}"}
        },
        {
          "id": "road_motorway",
          "type": "line",
          "source": "openmaptiles",
          "source-layer": "transportation",
          "filter": ["==", "class", "motorway"],
          "paint": {
            "line-color": "${_colorToHex(roadPrimaryColor)}",
            "line-width": 4,
            "line-opacity": 0.8
          }
        },
        {
          "id": "road_primary",
          "type": "line",
          "source": "openmaptiles",
          "source-layer": "transportation",
          "filter": ["==", "class", "primary"],
          "paint": {
            "line-color": "${_colorToHex(roadSecondaryColor)}",
            "line-width": 2.5,
            "line-opacity": 0.7
          }
        },
        {
          "id": "road_secondary",
          "type": "line",
          "source": "openmaptiles",
          "source-layer": "transportation",
          "filter": ["==", "class", "secondary"],
          "paint": {
            "line-color": "${_colorToHex(roadMinorColor)}",
            "line-width": 2,
            "line-opacity": 0.6
          }
        }
      ]
    }
  ''';
  
  // Leaflet CSS styles for 2.5D effect
  static String get leafletCssStyle => '''
    .building-base {
      fill: ${_colorToHex(buildingBaseColor)};
      stroke: #222222;
      stroke-width: 0.5;
      transition: fill 0.3s;
    }
    .building-top {
      fill: ${_colorToHex(buildingTopColor)};
      stroke: #333333;
      stroke-width: 0.5;
      transition: fill 0.3s;
    }
    .building-side {
      fill: ${_colorToHex(buildingSideColor)};
      stroke: #252525;
      stroke-width: 0.3;
      transition: fill 0.3s;
    }
    
    /* Highlight important roads */
    .road-motorway {
      stroke: #E0E0E0;
      stroke-width: 3;
      stroke-opacity: 0.8;
    }
    .road-primary {
      stroke: #D0D0D0;
      stroke-width: 2;
      stroke-opacity: 0.7;
    }
    .road-secondary {
      stroke: #AAAAAA;
      stroke-width: 1.5;
      stroke-opacity: 0.6;
    }
    
    /* Enhanced water styling */
    .water {
      fill: ${_colorToHex(waterColor)};
      opacity: 0.9;
    }
    .ocean {
      fill: ${_colorToHex(oceanDeepColor)};
      opacity: 0.95;
    }
    .river {
      fill: ${_colorToHex(riverColor)};
      opacity: 0.85;
    }
    .lake {
      fill: ${_colorToHex(lakeColor)};
      opacity: 0.9;
    }
    
    /* New POI styling */
    .poi-entertainment {
      fill: ${_colorToHex(entertainmentColor)};
      stroke: #111111;
      stroke-width: 0.5;
    }
    .poi-food {
      fill: ${_colorToHex(foodAndDrinkColor)};
      stroke: #111111;
      stroke-width: 0.5;
    }
    .poi-retail {
      fill: ${_colorToHex(retailColor)};
      stroke: #111111;
      stroke-width: 0.5;
    }
    .poi-transport {
      fill: ${_colorToHex(transportColor)};
      stroke: #111111;
      stroke-width: 0.5;
    }
    .poi-landmark {
      fill: ${_colorToHex(landmarkColor)};
      stroke: #111111;
      stroke-width: 0.5;
    }
  ''';
  
  // Helper function to convert Color to hex string
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  
  // Flutter Map TileLayer URL for similar styling
  static String get darkMapTileUrl => 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  
  // Alternative free map URL if the above is not available
  static String get fallbackMapTileUrl => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
} 