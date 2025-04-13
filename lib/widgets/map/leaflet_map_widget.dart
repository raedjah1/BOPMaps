import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../config/constants.dart';
import '../../providers/map_provider.dart';
import 'map_styles.dart';

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
    
    final pins = widget.mapProvider.pins;
    final pinsJson = jsonEncode(pins);
    
    _controller.runJavaScript('updatePins($pinsJson)');
  }
  
  /// Updates the map tilt factor (0-1)
  void _updateTilt(double tiltFactor) {
    if (!_isMapReady) return;
    
    _tiltFactor = tiltFactor;
    _controller.runJavaScript('setMapTilt($tiltFactor)');
  }
  
  /// Handles a location update from the provider
  void _handleLocationUpdate() {
    if (!_isMapReady || widget.mapProvider.currentPosition == null) return;
    
    final lat = widget.mapProvider.currentPosition!.latitude;
    final lng = widget.mapProvider.currentPosition!.longitude;
    final heading = widget.mapProvider.currentPosition!.heading ?? 0.0;
    
    _controller.runJavaScript('updateUserLocation($lat, $lng, $heading)');
    
    // If tracking is enabled, center the map on the user
    if (widget.mapProvider.isLocationTracking) {
      _controller.runJavaScript('animateToLocation($lat, $lng, 16)');
    }
  }
  
  /// Builds the HTML content for the Leaflet map with 2.5D effects
  String _buildLeafletHtml() {
    final initialLat = widget.mapProvider.currentPosition?.latitude ?? AppConstants.defaultLatitude;
    final initialLng = widget.mapProvider.currentPosition?.longitude ?? AppConstants.defaultLongitude;
    final initialZoom = AppConstants.defaultZoom;
    
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>Leaflet Map</title>
        <style>
          body {
            margin: 0;
            padding: 0;
          background-color: ${_colorToCss(MapStyles.backgroundColor)};
          }
          #map {
            width: 100%;
          height: 100vh;
          position: absolute;
        }
        .center-marker {
          width: 24px;
          height: 24px;
          border-radius: 50%;
          background-color: ${_colorToCss(Theme.of(context).primaryColor)};
          border: 2px solid white;
          box-shadow: 0 2px 5px rgba(0,0,0,0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          transform: translate(-50%, -50%);
        }
        .center-marker:after {
          content: '';
          width: 0;
          height: 0;
          border-left: 6px solid transparent;
          border-right: 6px solid transparent;
          border-top: 6px solid white;
          position: absolute;
          bottom: -6px;
          left: calc(50% - 6px);
          }
        .pulse-circle {
          position: absolute;
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background-color: ${_colorToCss(Theme.of(context).primaryColor.withOpacity(0.3))};
          transform: translate(-50%, -50%) scale(0);
          animation: pulse 1.5s infinite;
          }
        @keyframes pulse {
          0% { transform: translate(-50%, -50%) scale(0); opacity: 1; }
          100% { transform: translate(-50%, -50%) scale(1); opacity: 0; }
        }
        .heading-indicator {
          width: 0;
          height: 0;
          border-left: 6px solid transparent;
          border-right: 6px solid transparent;
          border-bottom: 10px solid white;
          position: absolute;
          top: -12px;
          left: calc(50% - 6px);
            transform-origin: bottom center;
        }
        .shadow {
          position: absolute;
          width: 18px;
          height: 2px;
          border-radius: 50%;
          background-color: rgba(0,0,0,0.2);
          bottom: -4px;
          left: 50%;
          transform: translateX(-50%);
        }
        
        /* Map overlay with shadow for depth effect */
        .map-overlay {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          pointer-events: none;
          background-image: linear-gradient(
            to bottom,
            rgba(255,255,255,0.1) 0%,
            rgba(0,0,0,0.15) 100%
          );
          opacity: 0; /* Start invisible until tilt is activated */
          transition: opacity 0.5s ease;
        }
        
        /* Loading overlay */
        #loading {
            position: absolute;
            top: 0;
            left: 0;
          width: 100%;
          height: 100%;
          background-color: ${_colorToCss(MapStyles.backgroundColor)};
            display: flex;
          align-items: center;
            justify-content: center;
            z-index: 1000;
          }
          .spinner {
          width: 40px;
          height: 40px;
            border: 4px solid rgba(255,255,255,0.3);
            border-radius: 50%;
          border-top-color: white;
            animation: spin 1s linear infinite;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        
        /* Building styling from our map_styles.dart */
        ${MapStyles.leafletCssStyle}
        </style>
      
      <!-- Include Leaflet CSS and JS -->
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.3/dist/leaflet.css" />
      <script src="https://unpkg.com/leaflet@1.9.3/dist/leaflet.js"></script>
      
      <!-- Include D3.js for advanced 2.5D visualizations -->
        <script src="https://d3js.org/d3.v7.min.js"></script>
      </head>
      <body>
      <!-- Map container -->
        <div id="map"></div>
      
      <!-- Loading overlay -->
      <div id="loading">
          <div class="spinner"></div>
        </div>
      
      <!-- Map overlay for shadow/lighting effects -->
      <div id="map-overlay" class="map-overlay"></div>
        
        <script>
        // Map variables
          let map;
          let buildingLayer;
          let pinLayer;
        let userLocationMarker;
        let buildings = [];
        let mapTilt = 0.0;
          let leafletMapReady = false;
          
        // Initialize the map when the page loads
        document.addEventListener('DOMContentLoaded', initMap);
        
        // Initialize Leaflet map with CartoDB dark basemap
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
          L.tileLayer('${MapStyles.darkMapTileUrl}', {
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
          window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
            leafletMapReady = true;
            });
          }
          
        // Set the map tilt value (0-1)
        function setMapTilt(tiltValue) {
          if (!leafletMapReady) return;
          
          mapTilt = tiltValue;
          
          // Update the overlay opacity based on tilt
          document.getElementById('map-overlay').style.opacity = tiltValue * 0.8;
          
          // Re-render with new tilt value
          renderBuildings();
        }
        
        // Animate to location with smooth movement
        function animateToLocation(lat, lng, zoom) {
          if (!leafletMapReady) return;
          
          map.flyTo([lat, lng], zoom, {
            duration: ${MapStyles.cameraMoveAnimationDuration.inMilliseconds / 1000},
            easeLinearity: 0.25
          });
        }
        
        // Update user's location marker
        function updateUserLocation(lat, lng, heading) {
          if (!leafletMapReady) return;
          
          if (!userLocationMarker) {
            // Create marker if it doesn't exist
            userLocationMarker = createUserLocationMarker(lat, lng, heading);
            userLocationMarker.addTo(map);
          } else {
            // Update existing marker position
            userLocationMarker.setLatLng([lat, lng]);
            
            // Update heading if available
            const headingIndicator = userLocationMarker.getElement().querySelector('.heading-indicator');
            if (headingIndicator) {
              headingIndicator.style.transform = \`rotate(\${heading}deg)\`;
            }
          }
        }
        
        // Create user location marker with pulse effect
        function createUserLocationMarker(lat, lng, heading) {
          const userIcon = L.divIcon({
            className: 'user-location-marker',
            html: \`
              <div class="pulse-circle"></div>
              <div class="center-marker">
                <div class="heading-indicator" style="transform: rotate(\${heading}deg)"></div>
                <div class="shadow"></div>
              </div>
            \`,
            iconSize: [24, 24],
            iconAnchor: [12, 12]
          });
          
          return L.marker([lat, lng], { icon: userIcon, zIndexOffset: 1000 });
              }
              
        // Update pins on the map
        function updatePins(pins) {
          if (!leafletMapReady) return;
          
          // Clear existing pins
          d3.select('#map-pins').selectAll('.pin').remove();
          
          // Add new pins
          const svgContainer = d3.select('#map-pins');
          
          pins.forEach(pin => {
            const lat = pin.latitude || 0;
            const lng = pin.longitude || 0;
            const point = map.latLngToLayerPoint(L.latLng(lat, lng));
            
            // Calculate pin size based on rarity
            let pinSize = 12;
            let pinColor = '${_colorToCss(Theme.of(context).primaryColor)}';
            
            switch(pin.rarity) {
              case 'Uncommon':
                pinSize = 14;
                pinColor = '#4CAF50';
                break;
              case 'Rare':
                pinSize = 16;
                pinColor = '#2196F3';
                break;
              case 'Epic':
                pinSize = 18;
                pinColor = '#9C27B0';
                break;
              case 'Legendary':
                pinSize = 20;
                pinColor = '#FFC107';
                break;
            }
            
            // Create pin group
            const pinGroup = svgContainer.append('g')
              .attr('class', 'pin')
              .attr('data-id', pin.id)
              .attr('transform', \`translate(\${point.x}, \${point.y})\`)
              .style('cursor', 'pointer')
              .on('click', () => {
                // Send pin click event to Flutter
                window.flutter_inappwebview.callHandler('onPinTap', pin);
              });
            
            // Draw pin with shadow
            drawPin(pinGroup, pinSize, pinColor);
          });
        }
        
        // Draw a pin with shadow and 2.5D effect
        function drawPin(group, size, color) {
          const pinHeight = size * 1.5;
          const shadowOffset = mapTilt * size * 0.3;
              
          // Draw shadow
          group.append('ellipse')
            .attr('cx', shadowOffset)
            .attr('cy', shadowOffset)
            .attr('rx', size * 0.6)
            .attr('ry', size * 0.3)
            .attr('fill', 'rgba(0,0,0,0.3)');
          
          // Draw pin head
          group.append('circle')
            .attr('class', 'pin-head')
            .attr('r', size)
            .attr('cx', 0)
            .attr('cy', -pinHeight / 2)
            .attr('fill', color)
            .attr('stroke', 'white')
            .attr('stroke-width', 2);
          
          // Draw pin tail
          group.append('path')
            .attr('class', 'pin-tail')
            .attr('d', \`M \${-size/2} \${-pinHeight/2} L 0 \${pinHeight/2} L \${size/2} \${-pinHeight/2} Z\`)
            .attr('fill', color);
        }
        
        // Update map when view changes
        function updateMap() {
          if (!leafletMapReady) return;
          
          // Update buildings and pins
          renderBuildings();
        }
        
        // Handle map click
        function onMapClick(e) {
          // Get click coordinates
          const lat = e.latlng.lat;
          const lng = e.latlng.lng;
          
          // Pass click to Flutter
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onMapClick', { latitude: lat, longitude: lng });
          }
        }
        
        // Fetch building data from OpenStreetMap
        async function fetchBuildingData() {
          try {
            const bounds = map.getBounds();
            const querySouth = bounds.getSouth();
            const queryWest = bounds.getWest();
            const queryNorth = bounds.getNorth();
            const queryEast = bounds.getEast();
                
            // Limit the query size to avoid too much data
            const querySize = (queryNorth - querySouth) * (queryEast - queryWest);
            if (querySize > 0.01) {
              console.log('Area too large, reducing query size');
              const center = map.getCenter();
              const lat = center.lat;
              const lng = center.lng;
              const reducedSize = 0.005;  // ~500m at equator
              
              return fetchBuildingData({
                south: lat - reducedSize,
                west: lng - reducedSize,
                north: lat + reducedSize,
                east: lng + reducedSize
              });
              }
              
              const query = `
                [out:json][timeout:25];
                (
                  way["building"](${querySouth},${queryWest},${queryNorth},${queryEast});
                );
                out body geom;
              `;
              
              console.log('Fetching building data for area:', querySouth, queryWest, queryNorth, queryEast);
              
              const response = await fetch('https://overpass-api.de/api/interpreter', {
                method: 'POST',
                body: query,
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent': 'BOPMaps/1.0'
                }
              });
              
              if (!response.ok) {
                throw new Error(`Network response was not ok: ${response.status} ${response.statusText}`);
              }
              
              const data = await response.json();
              console.log(`Received ${data.elements ? data.elements.length : 0} buildings`);
              return data.elements || [];
            } catch (error) {
              console.error('Error fetching building data:', error);
              return [];
            }
          }
          
          // Setup buildings based on real OSM data
          async function setupBuildings() {
            // Fetch real building data
            const buildingData = await fetchBuildingData();
            
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
            
            // Render buildings in 2.5D
            renderBuildings();
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
              
            // Add shadow projection based on light direction
            const shadowColor = 'rgba(0,0,0,0.2)';
            const shadowOffset = heightPixels * 0.5;
            const shadowPoints = screenPoints.map(p => 
              `${p.x + shadowOffset},${p.y + shadowOffset * 0.5}`
            ).join(' ');
            
            buildingGroup.append('polygon')
              .attr('class', 'building-shadow')
              .attr('points', shadowPoints)
              .attr('fill', shadowColor)
              .attr('opacity', 0.6 * mapTilt)
              .lower(); // Place shadow behind the building
              
              // Base polygon (ground footprint)
              buildingGroup.append('polygon')
                .attr('class', 'building-base')
              .attr('points', screenPoints.map(p => `${p.x},${p.y}`).join(' '));
              
              // Top polygon (roof) - offset by height
              buildingGroup.append('polygon')
                .attr('class', 'building-top')
              .attr('points', screenPoints.map(p => `${p.x},${p.y - heightPixels}`).join(' '));
              
            // Add sides to connect base and roof (walls)
              for (let i = 0; i < screenPoints.length; i++) {
              const p1 = screenPoints[i];
              const p2 = screenPoints[(i + 1) % screenPoints.length];
              
              // Skip if points are identical
              if (p1.x === p2.x && p1.y === p2.y) continue;
              
              // Calculate if this wall faces east/west for lighting
              const dx = p2.x - p1.x;
              const length = Math.sqrt(dx * dx + Math.pow(p2.y - p1.y, 2));
              const normalizedDx = length > 0 ? dx / length : 0;
            
              // Determine side color based on orientation (for lighting)
              let sideClass = 'building-side';
              if (normalizedDx > 0.3) {
                sideClass += ' building-side-light'; // Light side (east)
              } else if (normalizedDx < -0.3) {
                sideClass += ' building-side-dark';  // Dark side (west)
              }
              
              buildingGroup.append('polygon')
                .attr('class', sideClass)
                .attr('points', `
                  ${p1.x},${p1.y} 
                  ${p2.x},${p2.y} 
                  ${p2.x},${p2.y - heightPixels} 
                  ${p1.x},${p1.y - heightPixels}
                `);
            }
            
            // Add windows to large buildings
            if (heightPixels > 20 && map.getZoom() >= 16) {
              addWindows(buildingGroup, screenPoints, heightPixels);
            }
            });
          }
          
        // Add windows to building sides for visual interest
        function addWindows(buildingGroup, points, height) {
          // Find the longest side to add windows
          let maxLength = 0;
          let maxIdx = 0;
          
          for (let i = 0; i < points.length; i++) {
            const p1 = points[i];
            const p2 = points[(i + 1) % points.length];
            const length = Math.sqrt(Math.pow(p2.x - p1.x, 2) + Math.pow(p2.y - p1.y, 2));
            
            if (length > maxLength) {
              maxLength = length;
              maxIdx = i;
            }
          }
          
          // Skip if longest side is too short
          if (maxLength < 30) return;
          
          const p1 = points[maxIdx];
          const p2 = points[(maxIdx + 1) % points.length];
            
          // Calculate window spacing
          const windowCount = Math.floor(maxLength / 15);
          const rowCount = Math.floor(height / 15);
          
          // Draw windows
          for (let row = 0; row < rowCount; row++) {
            // Skip ground floor for realism
            const rowY = height - (row + 1) * (height / (rowCount + 1));
            
            for (let col = 0; col < windowCount; col++) {
              const t = (col + 1) / (windowCount + 1);
              const windowX = p1.x + (p2.x - p1.x) * t;
              const windowY = p1.y + (p2.y - p1.y) * t - rowY;
              
              // Randomly lit windows
              if (Math.random() > 0.4) {
                buildingGroup.append('rect')
                  .attr('x', windowX - 1.5)
                  .attr('y', windowY - 2.5)
                  .attr('width', 3)
                  .attr('height', 5)
                  .attr('fill', 'rgba(255,255,255,0.6)');
              }
            }
          }
          }
        </script>
      </body>
      </html>
    ''';
  }
  
  /// Converts a Flutter Color to CSS-compatible color string
  String _colorToCss(Color color) {
    if (color.opacity < 1.0) {
      return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${color.opacity})';
    } else {
      return 'rgb(${color.red}, ${color.green}, ${color.blue})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isMapReady)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
} 