import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../config/constants.dart';
import '../../providers/map_provider.dart';

/// A widget that embeds an actual Leaflet.js map in a WebView for advanced 2.5D features
class LeafletMapWidget extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(Map<String, dynamic>) onPinTap;

  const LeafletMapWidget({
    Key? key,
    required this.mapProvider,
    required this.onPinTap,
  }) : super(key: key);

  @override
  State<LeafletMapWidget> createState() => _LeafletMapWidgetState();
}

class _LeafletMapWidgetState extends State<LeafletMapWidget> {
  late WebViewController _controller;
  double _tiltFactor = 0.5; // Initial tilt (0-1)
  bool _isMapReady = false;
  
  @override
  void initState() {
    super.initState();
    _initWebView();
  }
  
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onMapLoaded();
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildLeafletHtml());
  }
  
  void _onMapLoaded() {
    setState(() {
      _isMapReady = true;
    });
    
    // Update map with pins
    _updateMapPins();
    
    // Set initial tilt
    _updateTilt(_tiltFactor);
  }
  
  /// Updates the map with the current pins from the provider
  void _updateMapPins() {
    if (!_isMapReady) return;
    
    final pinsJson = jsonEncode(widget.mapProvider.pins.map((pin) {
      // Convert pin to map if it's not already
      final pinData = pin is Map<String, dynamic> ? pin : pin.toJson();
      return pinData;
    }).toList());
    
    _controller.runJavaScript('updateMapPins($pinsJson)');
  }
  
  /// Updates the map tilt factor (0-1)
  void _updateTilt(double tiltFactor) {
    if (!_isMapReady) return;
    
    _controller.runJavaScript('setMapTilt($tiltFactor)');
    setState(() {
      _tiltFactor = tiltFactor;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The WebView containing the Leaflet map
        WebViewWidget(controller: _controller),
        
        // Loading indicator
        if (!_isMapReady)
          const Center(
            child: CircularProgressIndicator(),
          ),
        
        // Tilt controls
        Positioned(
          top: 16,
          right: 16,
          child: _buildTiltControls(),
        ),
        
        // Map controls - moved to the right side with more spacing
        Positioned(
          bottom: 16,
          right: 24, // Increased right padding
          child: _buildMapControls(),
        ),
      ],
    );
  }
  
  Widget _buildTiltControls() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '2.5D View: ${(_tiltFactor * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Slider(
                value: _tiltFactor,
                min: 0.0,
                max: 1.0,
                onChanged: _updateTilt,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMapControlButton(
          icon: Icons.add,
          onPressed: () => _controller.runJavaScript('zoomIn()'),
          tooltip: 'Zoom In',
        ),
        const SizedBox(height: 12), // Increased spacing
        _buildMapControlButton(
          icon: Icons.remove,
          onPressed: () => _controller.runJavaScript('zoomOut()'),
          tooltip: 'Zoom Out',
        ),
        const SizedBox(height: 24), // Extra spacing before location button
        _buildMapControlButton(
          icon: Icons.my_location,
          onPressed: () => _controller.runJavaScript('resetView()'),
          tooltip: 'Reset Location',
        ),
        const SizedBox(height: 12), // Increased spacing
        _buildMapControlButton(
          icon: Icons.refresh,
          onPressed: () => _controller.runJavaScript('resetRotation()'),
          tooltip: 'Reset Rotation',
        ),
      ],
    );
  }
  
  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Builds the HTML with embedded Leaflet.js for the WebView
  String _buildLeafletHtml() {
    final initialLat = AppConstants.defaultLatitude;
    final initialLng = AppConstants.defaultLongitude;
    final initialZoom = AppConstants.defaultZoom;
    
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <title>BOP Maps 2.5D</title>
        <style>
          body {
            margin: 0;
            padding: 0;
            height: 100vh;
            width: 100vw;
            overflow: hidden;
          }
          #map {
            height: 100%;
            width: 100%;
            background-color: #121212;
          }
          /* Tilt perspective */
          .leaflet-container {
            transition: transform 0.5s ease-out, filter 0.5s ease;
          }
          /* Building styling */
          .building-base {
            fill: #323232;
            stroke: #292929;
            stroke-width: 1;
            transition: fill 0.3s;
          }
          .building-top {
            fill: #4A4A4A;
            stroke: #3A3A3A;
            stroke-width: 1;
            transition: fill 0.3s;
          }
          .building-side {
            fill: #2A2A2A;
            stroke: #232323;
            stroke-width: 1;
            transition: fill 0.3s;
          }
          /* Pin styling */
          .map-pin {
            filter: drop-shadow(0 var(--shadow-offset) var(--shadow-blur) rgba(0,0,0,var(--shadow-opacity)));
            transition: transform 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            transform-origin: bottom center;
            cursor: pointer;
          }
          .map-pin:hover {
            transform: scale(1.1) translateY(-3px);
          }
          .map-pin.dropping {
            animation: dropPin 1s cubic-bezier(0.175, 0.885, 0.32, 1.275);
          }
          @keyframes dropPin {
            0% { transform: translateY(-300px) scale(0.5); }
            60% { transform: translateY(10px) scale(1.1); }
            80% { transform: translateY(-5px); }
            100% { transform: translateY(0); }
          }
          /* Loading styles */
          .loading-overlay {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.7);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
            color: white;
            font-family: sans-serif;
          }
          .spinner {
            border: 4px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top: 4px solid #fff;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin-right: 10px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
        <!-- Leaflet CSS and JS -->
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <!-- D3.js for enhanced visualizations -->
        <script src="https://d3js.org/d3.v7.min.js"></script>
      </head>
      <body>
        <div id="map"></div>
        <div id="loading" class="loading-overlay">
          <div class="spinner"></div>
          <div>Loading 2.5D Map...</div>
        </div>
        
        <script>
          // Set default CSS variables for shadow
          document.documentElement.style.setProperty('--shadow-offset', '5px');
          document.documentElement.style.setProperty('--shadow-blur', '10px');
          document.documentElement.style.setProperty('--shadow-opacity', '0.5');
          
          // Global variables
          let map;
          let pins = [];
          let buildings = [];
          let waterBodies = [];
          let landscapeFeatures = [];
          let mapTilt = 0.5; // Default tilt factor (0-1)
          let mapRotation = 0; // Map rotation in degrees
          let buildingLayer;
          let pinLayer;
          let waterLayer;
          let landscapeLayer;
          let leafletMapReady = false;
          
          // Initialize Leaflet map
          function initMap() {
            // Create a map with custom options
            map = L.map('map', {
              center: [${initialLat}, ${initialLng}],
              zoom: ${initialZoom},
              maxZoom: 19,
              minZoom: 2,  // Allow zooming out to see more of the world
              zoomControl: false, // We'll add custom controls
              attributionControl: false, // Attribution is added elsewhere
              worldCopyJump: true,  // Enable wrapping around the world
            });
            
            // Add tile layer (use a modern styled map)
            L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
              subdomains: 'abcd',
              maxZoom: 19,
              attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
            }).addTo(map);
            
            // Create SVG overlay for 2.5D features
            buildingLayer = L.svg().addTo(map);
            pinLayer = L.svg().addTo(map);
            
            // Add ID to the SVG layers for easier selection
            d3.select(buildingLayer._container).attr('id', 'map-buildings');
            d3.select(pinLayer._container).attr('id', 'map-pins');
            
            // Add map event listeners
            map.on('zoomend', updateMap);
            map.on('moveend', updateMap);
            map.on('click', onMapClick);
            
            // Hide loading overlay
            document.getElementById('loading').style.display = 'none';
            
            // Setup buildings and features
            setupBuildings();
            
            // Set flag that map is ready
            leafletMapReady = true;
            
            // Handle communication from Flutter
            window.addEventListener('flutterInAppWebViewPlatformReady', function(event) {
              window.flutter_inappwebview.callHandler('mapReady');
            });
          }
          
          // Initialize map when page is loaded
          window.onload = initMap;
          
          // Fetch building data from Overpass API
          async function fetchBuildingData() {
            const bounds = map.getBounds();
            
            try {
              // Ensure bounds are valid before querying
              if (!bounds || !bounds.isValid()) {
                console.error('Map bounds are invalid or not ready');
                return [];
              }
              
              // Limit the query area to prevent overloading the API
              // Use a smaller region if the viewing area is very large
              const south = bounds.getSouth();
              const west = bounds.getWest();
              const north = bounds.getNorth();
              const east = bounds.getEast();
              
              // Check if area is too large (more than ~5km²) and reduce it
              const latDiff = north - south;
              const lonDiff = east - west;
              
              let querySouth = south;
              let queryWest = west;
              let queryNorth = north;
              let queryEast = east;
              
              if (latDiff > 0.05 || lonDiff > 0.05) {
                // Calculate center point
                const centerLat = south + latDiff/2;
                const centerLon = west + lonDiff/2;
                
                // Reduce query area to a reasonable size
                querySouth = centerLat - 0.025;
                queryWest = centerLon - 0.025;
                queryNorth = centerLat + 0.025;
                queryEast = centerLon + 0.025;
                
                console.log('Reducing query area to prevent API overload');
              }
              
              // List of Overpass API endpoints to try
              const endpoints = [
                'https://overpass-api.de/api/interpreter',
                'https://overpass.kumi.systems/api/interpreter',
                'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
              ];
              
              // Properly formatted Overpass QL query
              const query = `
                [out:json][timeout:25];
                (
                  way["building"](${querySouth},${queryWest},${queryNorth},${queryEast});
                );
                out body geom;
              `;
              
              console.log('Fetching building data for area:', querySouth, queryWest, queryNorth, queryEast);
              
              // Try each endpoint until one works
              let response = null;
              let errorMessages = [];
              
              for (const endpoint of endpoints) {
                try {
                  console.log(`Trying endpoint: ${endpoint}`);
                  response = await fetch(endpoint, {
                    method: 'POST',
                    body: query,
                    headers: {
                      'Content-Type': 'application/x-www-form-urlencoded',
                      'User-Agent': 'BOPMaps/1.0 (Flutter App)'
                    },
                    // Shorter timeout to quickly move to the next endpoint if one fails
                    signal: AbortSignal.timeout(10000)
                  });
                  
                  if (response.ok) break;
                  errorMessages.push(`${endpoint} returned ${response.status}: ${response.statusText}`);
                } catch (err) {
                  errorMessages.push(`${endpoint} error: ${err.message}`);
                  continue;
                }
              }
              
              if (!response || !response.ok) {
                console.error('All Overpass API endpoints failed:', errorMessages.join('; '));
                return [];
              }
              
              const data = await response.json();
              console.log(`Received ${data.elements ? data.elements.length : 0} buildings`);
              return data.elements || [];
            } catch (error) {
              console.error('Error fetching building data:', error);
              return [];
            }
          }
          
          // Fetch water bodies data from Overpass API
          async function fetchWaterBodiesData() {
            const bounds = map.getBounds();
            
            try {
              // Ensure bounds are valid before querying
              if (!bounds || !bounds.isValid()) {
                console.error('Map bounds are invalid or not ready');
                return [];
              }
              
              // Limit the query area to prevent overloading the API
              const south = bounds.getSouth();
              const west = bounds.getWest();
              const north = bounds.getNorth();
              const east = bounds.getEast();
              
              // Check if area is too large and reduce it
              const latDiff = north - south;
              const lonDiff = east - west;
              
              let querySouth = south;
              let queryWest = west;
              let queryNorth = north;
              let queryEast = east;
              
              if (latDiff > 0.05 || lonDiff > 0.05) {
                // Calculate center point
                const centerLat = south + latDiff/2;
                const centerLon = west + lonDiff/2;
                
                // Reduce query area to a reasonable size
                querySouth = centerLat - 0.025;
                queryWest = centerLon - 0.025;
                queryNorth = centerLat + 0.025;
                queryEast = centerLon + 0.025;
                
                console.log('Reducing water bodies query area');
              }
              
              // List of Overpass API endpoints to try
              const endpoints = [
                'https://overpass-api.de/api/interpreter',
                'https://overpass.kumi.systems/api/interpreter',
                'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
              ];
              
              // Query for water bodies (lakes, rivers, etc.)
              const query = `
                [out:json][timeout:25];
                (
                  // Lakes and water areas
                  way["natural"="water"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  relation["natural"="water"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  
                  // Rivers
                  way["waterway"="river"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  way["waterway"="stream"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  
                  // Coastlines
                  way["natural"="coastline"](${querySouth},${queryWest},${queryNorth},${queryEast});
                );
                out body geom;
              `;
              
              // Try each endpoint until one works
              let response = null;
              let errorMessages = [];
              
              for (const endpoint of endpoints) {
                try {
                  console.log(`Trying endpoint for water: ${endpoint}`);
                  response = await fetch(endpoint, {
                    method: 'POST',
                    body: query,
                    headers: {
                      'Content-Type': 'application/x-www-form-urlencoded',
                      'User-Agent': 'BOPMaps/1.0 (Flutter App)'
                    },
                    signal: AbortSignal.timeout(10000)
                  });
                  
                  if (response.ok) break;
                  errorMessages.push(`${endpoint} returned ${response.status}: ${response.statusText}`);
                } catch (err) {
                  errorMessages.push(`${endpoint} error: ${err.message}`);
                  continue;
                }
              }
              
              if (!response || !response.ok) {
                console.error('All Overpass API endpoints failed for water bodies:', errorMessages.join('; '));
                return [];
              }
              
              const data = await response.json();
              console.log(`Received ${data.elements ? data.elements.length : 0} water features`);
              return data.elements || [];
            } catch (error) {
              console.error('Error fetching water bodies data:', error);
              return [];
            }
          }
          
          // Fetch landscape features data from Overpass API
          async function fetchLandscapeData() {
            const bounds = map.getBounds();
            
            try {
              // Ensure bounds are valid before querying
              if (!bounds || !bounds.isValid()) {
                console.error('Map bounds are invalid or not ready');
                return [];
              }
              
              // Limit the query area to prevent overloading the API
              const south = bounds.getSouth();
              const west = bounds.getWest();
              const north = bounds.getNorth();
              const east = bounds.getEast();
              
              // Check if area is too large and reduce it
              const latDiff = north - south;
              const lonDiff = east - west;
              
              let querySouth = south;
              let queryWest = west;
              let queryNorth = north;
              let queryEast = east;
              
              if (latDiff > 0.05 || lonDiff > 0.05) {
                // Calculate center point
                const centerLat = south + latDiff/2;
                const centerLon = west + lonDiff/2;
                
                // Reduce query area to a reasonable size
                querySouth = centerLat - 0.025;
                queryWest = centerLon - 0.025;
                queryNorth = centerLat + 0.025;
                queryEast = centerLon + 0.025;
                
                console.log('Reducing landscape query area');
              }
              
              // List of Overpass API endpoints to try
              const endpoints = [
                'https://overpass-api.de/api/interpreter',
                'https://overpass.kumi.systems/api/interpreter',
                'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
              ];
              
              // Query for landscape features (parks, forests, etc.)
              const query = `
                [out:json][timeout:25];
                (
                  // Parks and green areas
                  way["leisure"="park"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  relation["leisure"="park"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  
                  // Forests and woods
                  way["natural"="wood"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  relation["natural"="wood"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  
                  // Grassland
                  way["natural"="grassland"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  
                  // Other natural features
                  way["natural"="heath"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  way["natural"="scrub"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  way["landuse"="forest"](${querySouth},${queryWest},${queryNorth},${queryEast});
                  way["landuse"="meadow"](${querySouth},${queryWest},${queryNorth},${queryEast});
                );
                out body geom;
              `;
              
              // Try each endpoint until one works
              let response = null;
              let errorMessages = [];
              
              for (const endpoint of endpoints) {
                try {
                  console.log(`Trying endpoint for landscape: ${endpoint}`);
                  response = await fetch(endpoint, {
                    method: 'POST',
                    body: query,
                    headers: {
                      'Content-Type': 'application/x-www-form-urlencoded',
                      'User-Agent': 'BOPMaps/1.0 (Flutter App)'
                    },
                    signal: AbortSignal.timeout(10000)
                  });
                  
                  if (response.ok) break;
                  errorMessages.push(`${endpoint} returned ${response.status}: ${response.statusText}`);
                } catch (err) {
                  errorMessages.push(`${endpoint} error: ${err.message}`);
                  continue;
                }
              }
              
              if (!response || !response.ok) {
                console.error('All Overpass API endpoints failed for landscape features:', errorMessages.join('; '));
                return [];
              }
              
              const data = await response.json();
              console.log(`Received ${data.elements ? data.elements.length : 0} landscape features`);
              return data.elements || [];
            } catch (error) {
              console.error('Error fetching landscape data:', error);
              return [];
            }
          }
          
          // Setup buildings based on real OSM data
          async function setupBuildings() {
            try {
              // Create SVG layers for new feature types if they don't exist
              if (!waterLayer) {
                waterLayer = L.svg().addTo(map);
                d3.select(waterLayer._container).attr('id', 'map-water');
              }
              
              if (!landscapeLayer) {
                landscapeLayer = L.svg().addTo(map);
                d3.select(landscapeLayer._container).attr('id', 'map-landscape');
              }
              
              // Fetch all data types in parallel
              const [buildingData, waterData, landscapeData] = await Promise.all([
                fetchBuildingData(),
                fetchWaterBodiesData(),
                fetchLandscapeData()
              ]);
              
              // Process buildings
              buildings = buildingData.map(building => {
                // Extract or estimate height
                let height = 10; // Default height in meters
                if (building.tags && building.tags.height) {
                  height = parseFloat(building.tags.height) || height;
                } else if (building.tags && building.tags['building:levels']) {
                  height = parseFloat(building.tags['building:levels']) * 3 || height;
                }
                
                // Process geometry
                const points = building.geometry ? building.geometry.map(node => [node.lat, node.lon]) : [];
                
                return {
                  id: building.id,
                  height,
                  points,
                  tags: building.tags || {}
                };
              });
              
              // Process water bodies
              waterBodies = waterData.map(water => {
                // Determine water type
                let type = 'unknown';
                let elevation = 0.0; // Water is flat in most cases
                
                if (water.tags) {
                  if (water.tags.natural) {
                    type = water.tags.natural;
                  } else if (water.tags.waterway) {
                    type = water.tags.waterway;
                    
                    // Rivers and streams should have a slight elevation for visual appeal
                    if (type === 'river') {
                      elevation = 0.3;
                    } else if (type === 'stream') {
                      elevation = 0.2;
                    }
                  }
                }
                
                // Process geometry
                const points = water.geometry ? water.geometry.map(node => [node.lat, node.lon]) : [];
                
                return {
                  id: water.id,
                  type,
                  elevation,
                  points,
                  tags: water.tags || {}
                };
              });
              
              // Process landscape features
              landscapeFeatures = landscapeData.map(feature => {
                // Determine feature type
                let type = 'unknown';
                let elevation = 0.2; // Slight elevation for visual appeal
                
                if (feature.tags) {
                  if (feature.tags.natural) {
                    type = feature.tags.natural;
                    
                    // Adjust elevation based on natural feature type
                    if (type === 'wood') {
                      elevation = 0.5; // Forests have more elevation
                    }
                  } else if (feature.tags.leisure) {
                    type = feature.tags.leisure;
                  } else if (feature.tags.landuse) {
                    type = feature.tags.landuse;
                    
                    // Adjust elevation based on landuse
                    if (type === 'forest') {
                      elevation = 0.5;
                    }
                  }
                }
                
                // Process geometry
                const points = feature.geometry ? feature.geometry.map(node => [node.lat, node.lon]) : [];
                
                return {
                  id: feature.id,
                  type,
                  elevation,
                  points,
                  tags: feature.tags || {}
                };
              });
              
              // Render all layers
              renderLandscape();
              renderWaterBodies();
              renderBuildings();
              
            } catch (error) {
              console.error('Error setting up map features:', error);
            }
          }
          
          // Render landscape features with 2.5D effect
          function renderLandscape() {
            // Skip if map is not ready
            if (!leafletMapReady) return;
            
            // Get the svg container
            const svg = d3.select('#map-landscape');
            
            // Clear existing landscape features
            svg.selectAll('.landscape').remove();
            
            // Define colors for landscape types
            const colors = {
              park: '#62A87C',
              garden: '#7CB896',
              wood: '#2E8B57',
              forest: '#2E8B57',
              grassland: '#9BC088',
              meadow: '#9BC088',
              heath: '#A89968',
              scrub: '#8F9978',
              grass: '#A1C884',
              default: '#94B37B'
            };
            
            // Sort landscape features by elevation for proper rendering
            landscapeFeatures.sort((a, b) => a.elevation - b.elevation);
            
            // Draw each landscape feature
            landscapeFeatures.forEach(feature => {
              // Skip features with insufficient points
              if (feature.points.length < 3) return;
              
              // Calculate elevation based on tilt
              const heightPixels = feature.elevation * (mapTilt * 30);
              
              // Convert geo coordinates to screen coordinates
              const screenPoints = feature.points.map(point => {
                return map.latLngToLayerPoint(L.latLng(point[0], point[1]));
              });
              
              // Create feature group
              const featureGroup = svg.append('g')
                .attr('class', 'landscape')
                .attr('data-id', feature.id)
                .attr('data-type', feature.type);
              
              // Determine color based on feature type
              const color = colors[feature.type] || colors.default;
              
              // Base polygon (ground footprint with elevation)
              const points = screenPoints.map(p => \`\${p.x},\${p.y - heightPixels}\`).join(' ');
              
              // Create path for the feature
              featureGroup.append('polygon')
                .attr('points', points)
                .attr('fill', color)
                .attr('stroke', d3.color(color).darker(0.3))
                .attr('stroke-width', 1);
              
              // Add feature-specific details based on type
              if (feature.type === 'forest' || feature.type === 'wood') {
                // Add simplified tree symbols for forests when zoomed in enough
                if (map.getZoom() > 14 && mapTilt > 0.2) {
                  const bounds = {
                    minX: d3.min(screenPoints, d => d.x),
                    minY: d3.min(screenPoints, d => d.y),
                    maxX: d3.max(screenPoints, d => d.x),
                    maxY: d3.max(screenPoints, d => d.y)
                  };
                  
                  const area = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY);
                  const density = Math.min(area * 0.00005, 100);
                  
                  // Create random trees inside the polygon
                  for (let i = 0; i < density; i++) {
                    // Random position within bounding box
                    const x = bounds.minX + Math.random() * (bounds.maxX - bounds.minX);
                    const y = bounds.minY + Math.random() * (bounds.maxY - bounds.minY);
                    const point = {x, y};
                    
                    // Only add if point is actually inside the polygon
                    if (d3.polygonContains(screenPoints, [x, y])) {
                      const treeSize = 3 + Math.random() * 2;
                      
                      // Tree canopy (simplified triangle for modern look)
                      featureGroup.append('path')
                        .attr('d', \`M\${x},\${y - heightPixels - treeSize * 2} 
                                  L\${x - treeSize},\${y - heightPixels} 
                                  L\${x + treeSize},\${y - heightPixels} Z\`)
                        .attr('fill', d3.color(color).brighter(0.3))
                        .attr('stroke', 'none');
                      
                      // Tree trunk
                      featureGroup.append('rect')
                        .attr('x', x - treeSize * 0.15)
                        .attr('y', y - heightPixels)
                        .attr('width', treeSize * 0.3)
                        .attr('height', treeSize)
                        .attr('fill', '#8B5A2B');
                    }
                  }
                }
              } else if (feature.type === 'park' || feature.type === 'garden') {
                // Add path details for parks when zoomed in
                if (map.getZoom() > 15 && mapTilt > 0.2) {
                  const bounds = {
                    minX: d3.min(screenPoints, d => d.x),
                    minY: d3.min(screenPoints, d => d.y),
                    maxX: d3.max(screenPoints, d => d.x),
                    maxY: d3.max(screenPoints, d => d.y)
                  };
                  
                  // Add a simplified path
                  if (bounds.maxX - bounds.minX > 50) {
                    const pathData = \`M\${bounds.minX + (bounds.maxX - bounds.minX) * 0.2},\${bounds.minY + (bounds.maxY - bounds.minY) * 0.5 - heightPixels} 
                                      C\${bounds.minX + (bounds.maxX - bounds.minX) * 0.4},\${bounds.minY + (bounds.maxY - bounds.minY) * 0.3 - heightPixels} 
                                      \${bounds.minX + (bounds.maxX - bounds.minX) * 0.6},\${bounds.minY + (bounds.maxY - bounds.minY) * 0.7 - heightPixels} 
                                      \${bounds.minX + (bounds.maxX - bounds.minX) * 0.8},\${bounds.minY + (bounds.maxY - bounds.minY) * 0.5 - heightPixels}\`;
                                      
                    featureGroup.append('path')
                      .attr('d', pathData)
                      .attr('fill', 'none')
                      .attr('stroke', '#D2B48C')
                      .attr('stroke-width', 2)
                      .attr('stroke-linecap', 'round');
                  }
                }
              }
            });
          }
          
          // Render water bodies with 2.5D effect
          function renderWaterBodies() {
            // Skip if map is not ready
            if (!leafletMapReady) return;
            
            // Get the svg container
            const svg = d3.select('#map-water');
            
            // Clear existing water features
            svg.selectAll('.water').remove();
            
            // Define water colors
            const waterColor = '#2A93D5';
            const riverColor = '#4BABDB';
            
            // Current timestamp for wave animations
            const now = Date.now();
            
            // Draw each water body
            waterBodies.forEach(water => {
              // Skip water bodies with insufficient points
              if (water.points.length < 3) return;
              
              // Calculate elevation based on tilt
              const heightPixels = water.elevation * (mapTilt * 20);
              
              // Convert geo coordinates to screen coordinates
              const screenPoints = water.points.map(point => {
                return map.latLngToLayerPoint(L.latLng(point[0], point[1]));
              });
              
              // Create water group
              const waterGroup = svg.append('g')
                .attr('class', 'water')
                .attr('data-id', water.id)
                .attr('data-type', water.type);
              
              if (water.type === 'water' || water.type === 'coastline') {
                // Lakes and water areas
                // Base polygon for water
                const points = screenPoints.map(p => \`\${p.x},\${p.y - heightPixels}\`).join(' ');
                
                waterGroup.append('polygon')
                  .attr('points', points)
                  .attr('fill', waterColor)
                  .attr('stroke', d3.color(waterColor).darker(0.2))
                  .attr('stroke-width', 1);
                
                // Add subtle wave effect for water when tilt is significant
                if (mapTilt > 0.2 && map.getZoom() > 13) {
                  // Calculate a bounding box for the water feature
                  const bounds = {
                    minX: d3.min(screenPoints, d => d.x),
                    minY: d3.min(screenPoints, d => d.y),
                    maxX: d3.max(screenPoints, d => d.x),
                    maxY: d3.max(screenPoints, d => d.y)
                  };
                  
                  // Add some horizontal wave lines
                  const waveSpacing = 30;
                  for (let y = bounds.minY; y <= bounds.maxY; y += waveSpacing) {
                    const wavePoints = [];
                    
                    for (let x = bounds.minX; x <= bounds.maxX; x += 10) {
                      // Create a sine wave effect, animated with time
                      const waveHeight = Math.sin((x + now / 1000) / 20) * mapTilt * 2;
                      wavePoints.push([x, y - heightPixels + waveHeight]);
                    }
                    
                    // Check if the line has any points within the polygon
                    let hasPointInside = false;
                    for (const point of wavePoints) {
                      if (d3.polygonContains(screenPoints, point)) {
                        hasPointInside = true;
                        break;
                      }
                    }
                    
                    if (hasPointInside) {
                      const linePath = d3.line()(wavePoints);
                      
                      waterGroup.append('path')
                        .attr('d', linePath)
                        .attr('fill', 'none')
                        .attr('stroke', d3.color(waterColor).brighter(0.5))
                        .attr('stroke-width', 0.5)
                        .attr('stroke-opacity', 0.4);
                    }
                  }
                }
              } else if (water.type === 'river' || water.type === 'stream') {
                // Rivers and streams (lines with width)
                // Determine stroke width based on type and zoom
                const strokeWidth = water.type === 'river' 
                  ? 3 + map.getZoom() / 5 
                  : 1.5 + map.getZoom() / 7;
                
                // Create path for the river/stream
                const linePath = d3.line()(screenPoints.map(p => [p.x, p.y - heightPixels]));
                
                waterGroup.append('path')
                  .attr('d', linePath)
                  .attr('fill', 'none')
                  .attr('stroke', riverColor)
                  .attr('stroke-width', strokeWidth)
                  .attr('stroke-linecap', 'round')
                  .attr('stroke-linejoin', 'round');
                
                // Add flowing water effect with a lighter color
                if (mapTilt > 0.2 && map.getZoom() > 13) {
                  // Create a flowing pattern with sine wave
                  const flowingPoints = [];
                  
                  for (let i = 0; i < screenPoints.length; i++) {
                    const p = screenPoints[i];
                    const t = i / screenPoints.length;
                    const wave = Math.sin(t * Math.PI * 10 + now / 500) * mapTilt * strokeWidth * 0.3;
                    
                    flowingPoints.push([p.x + wave, p.y - heightPixels]);
                  }
                  
                  const flowPath = d3.line()(flowingPoints);
                  
                  waterGroup.append('path')
                    .attr('d', flowPath)
                    .attr('fill', 'none')
                    .attr('stroke', d3.color(riverColor).brighter(0.5))
                    .attr('stroke-width', strokeWidth * 0.5)
                    .attr('stroke-opacity', 0.6)
                    .attr('stroke-linecap', 'round')
                    .attr('stroke-linejoin', 'round');
                }
              }
            });
          }
          
          // Render buildings with 2.5D effect
          function renderBuildings() {
            // Skip if map is not ready
            if (!leafletMapReady) return;
            
            // Get the svg container
            const svg = d3.select('#map-buildings');
            
            // Clear existing buildings
            svg.selectAll('.building').remove();
            
            // Sort buildings by size for better rendering
            buildings.sort((a, b) => a.height - b.height);
            
            // Draw each building
            buildings.forEach(building => {
              // Skip buildings with insufficient points
              if (building.points.length < 3) return;
              
              // Convert geo coordinates to screen coordinates
              const screenPoints = building.points.map(point => map.latLngToLayerPoint(L.latLng(point[0], point[1])));
              
              // Calculate building height in pixels based on zoom
              const heightPixels = building.height * (0.5 + mapTilt * 0.5) * (map.getZoom() / 15);
              
              // Create building group
              const buildingGroup = svg.append('g')
                .attr('class', 'building')
                .attr('data-id', building.id);
              
              // Base polygon (ground footprint)
              buildingGroup.append('polygon')
                .attr('class', 'building-base')
                .attr('points', screenPoints.map(p => \`\${p.x},\${p.y}\`).join(' '));
              
              // Top polygon (roof) - offset by height
              buildingGroup.append('polygon')
                .attr('class', 'building-top')
                .attr('points', screenPoints.map(p => \`\${p.x},\${p.y - heightPixels}\`).join(' '));
              
              // Add sides
              for (let i = 0; i < screenPoints.length; i++) {
                const next = (i + 1) % screenPoints.length;
                const p1 = screenPoints[i];
                const p2 = screenPoints[next];
                
                buildingGroup.append('polygon')
                  .attr('class', 'building-side')
                .attr('points', \`
                    \${p1.x},\${p1.y} 
                    \${p2.x},\${p2.y} 
                    \${p2.x},\${p2.y - heightPixels} 
                    \${p1.x},\${p1.y - heightPixels}
                  \`);
              }
            });
          }
          
          // Update the map when view changes
          function updateMap() {
            // Skip if map is not ready
            if (!leafletMapReady) return;
            
            // Update all visualization layers
            renderLandscape();
            renderWaterBodies();
            renderBuildings();
            updatePins();
            
            // Update perspective transform based on current settings
            updateMapTransform();
          }
          
          // Add or update pins on the map
          function updateMapPins(pinData) {
            // Update pins array
            pins = pinData || [];
            
            // Render pins
            updatePins();
          }
          
          // Render pins with 2.5D effect
          function updatePins() {
            // Skip if map is not ready
            if (!leafletMapReady) return;
            
            // Get the svg container
            const svg = d3.select('#map-pins');
            
            // Clear existing pins
            svg.selectAll('.map-pin').remove();
            
            // Draw each pin
            pins.forEach(pin => {
              const position = map.latLngToLayerPoint(L.latLng(pin.latitude, pin.longitude));
              
              // Pin color based on rarity
              const pinColors = {
                'Common': '#808080',
                'Uncommon': '#4CAF50',
                'Rare': '#2196F3',
                'Epic': '#9C27B0',
                'Legendary': '#FFC107'
              };
              
              const pinColor = pinColors[pin.rarity] || '#FF5722';
              const isCollected = pin.is_collected;
              
              // Create pin group
              const pinGroup = svg.append('g')
                .attr('class', 'map-pin')
                .attr('data-id', pin.id)
                .attr('transform', \`translate(\${position.x}, \${position.y})\`);
              
              // Pin body
              pinGroup.append('path')
                .attr('d', 'M0,-30 C-8,-30 -15,-23 -15,-15 C-15,-7 -8,0 0,8 C8,0 15,-7 15,-15 C15,-23 8,-30 0,-30 Z')
                .attr('fill', pinColor)
                .attr('stroke', '#000')
                .attr('stroke-width', '1.5');
              
              // Pin circle for collected status
              pinGroup.append('circle')
                .attr('cx', 0)
                .attr('cy', -15)
                .attr('r', 5)
                .attr('fill', isCollected ? '#fff' : '#333')
                .attr('stroke', '#000')
                .attr('stroke-width', '1');
              
              // Pin shadow
              pinGroup.append('ellipse')
                .attr('cx', 0)
                .attr('cy', 8)
                .attr('rx', 10)
                .attr('ry', 3)
                .attr('fill', 'rgba(0,0,0,0.5)')
                .attr('filter', 'blur(2px)');
              
              // Add click handler
              pinGroup.on('click', () => {
                onPinClick(pin);
              });
            });
          }
          
          // Add a new pin at the clicked position
          function onMapClick(e) {
            // Optional: Implement click-to-add-pin functionality
            // This would require communication back to Flutter
          }
          
          // Handle pin click
          function onPinClick(pin) {
            // Send event to Flutter
            window.flutter_inappwebview.callHandler('onPinTap', pin);
          }
          
          // Add a new pin with animation
          function addPin(pinData) {
            // Add to pins array
            pins.push(pinData);
            
            // Update pins
            updatePins();
            
            // Get the newly added pin and animate it
            const svg = d3.select('#map-pins');
            const pinElement = svg.select(\`.map-pin[data-id="\${pinData.id}"]\`);
            
            if (!pinElement.empty()) {
              pinElement.classed('dropping', true);
              setTimeout(() => {
                pinElement.classed('dropping', false);
              }, 1000);
            }
          }
          
          function updateMapTransform() {
            // Calculate perspective transform based on tilt
            const container = map.getContainer();
            const perspective = 500; // perspective distance
            
            // Apply the CSS transformation
            container.style.transformOrigin = '50% 50%';
            container.style.transform = \`
              perspective(\${perspective}px)
              rotateX(\${mapTilt * 45}deg)
              rotateZ(\${mapRotation}deg)
            \`;
            
            // Also update shadow and lighting effects
            document.documentElement.style.setProperty('--shadow-offset', \`\${mapTilt * 10}px\`);
            document.documentElement.style.setProperty('--shadow-blur', \`\${mapTilt * 15}px\`);
            document.documentElement.style.setProperty('--shadow-opacity', \`\${mapTilt * 0.5}\`);
          }
          
          // Set map tilt (0-1)
          function setMapTilt(tiltFactor) {
            mapTilt = tiltFactor;
            updateMapTransform();
            renderBuildings();
          }
          
          // Set map rotation (degrees)
          function setMapRotation(degrees) {
            mapRotation = degrees;
            updateMapTransform();
          }
          
          // Reset map view
          function resetView() {
            map.setView([${initialLat}, ${initialLng}], ${initialZoom});
          }
          
          // Zoom in
          function zoomIn() {
            map.zoomIn();
          }
          
          // Zoom out
          function zoomOut() {
            map.zoomOut();
          }
          
          // Reset rotation
          function resetRotation() {
            mapRotation = 0;
            updateMapTransform();
          }
        </script>
      </body>
      </html>
    ''';
  }
} 