import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// Temporarily commenting out mapbox import
// import 'package:mapbox_gl/mapbox_gl.dart';
import '../config/constants.dart';
import '../models/pin.dart';
import '../services/api/pins_service.dart';
import '../services/location/location_service.dart';

// Basic LatLng class to replace Mapbox's version
class LatLng {
  final double latitude;
  final double longitude;
  
  const LatLng(this.latitude, this.longitude);
}

// Simple Camera position class to replace Mapbox's version
class CameraPosition {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt;
  
  const CameraPosition({
    required this.target,
    this.zoom = 14.0,
    this.bearing = 0.0,
    this.tilt = 0.0,
  });
}

// Simplified MapController to replace Mapbox's MapboxMapController
class MapController {
  // Method stubs for camera movement
  void animateCamera(CameraUpdate update) {
    // To be implemented with Leaflet
  }
  
  // Method to convert lat/lng to screen coordinates
  Point toScreenLocation(LatLng latLng) {
    // To be implemented with Leaflet
    return Point(0, 0);
  }
}

// Simple Point class to replace Mapbox's Point
class Point {
  final double x;
  final double y;
  
  const Point(this.x, this.y);
}

// Simple Camera update class to replace Mapbox's CameraUpdate
class CameraUpdate {
  final LatLng? latLng;
  final double? zoom;
  
  CameraUpdate._({this.latLng, this.zoom});
  
  static CameraUpdate newLatLng(LatLng latLng) {
    return CameraUpdate._(latLng: latLng);
  }
  
  static CameraUpdate newLatLngZoom(LatLng latLng, double zoom) {
    return CameraUpdate._(latLng: latLng, zoom: zoom);
  }
}

class MapProvider with ChangeNotifier {
  final PinsService _pinsService = PinsService();
  final LocationService _locationService = LocationService();
  
  // Map controller
  MapController? _mapController;
  
  // User location
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  // Map state
  double _zoom = AppConstants.defaultZoom;
  double _bearing = 0.0;
  double _pitch = AppConstants.defaultPitch;
  bool _isMapLoading = true;
  bool _isLocationTracking = false;
  
  // Pins
  List<Pin> _nearbyPins = [];
  bool _isPinsLoading = false;
  Pin? _selectedPin;
  double _searchRadius = AppConstants.pinDiscoveryRadius;
  
  // Error handling
  bool _hasNetworkError = false;
  String _errorMessage = '';
  bool _isAutoRetryScheduled = false;
  
  // Getters
  MapController? get mapController => _mapController;
  Position? get currentPosition => _currentPosition;
  double get zoom => _zoom;
  double get bearing => _bearing;
  double get pitch => _pitch;
  bool get isMapLoading => _isMapLoading;
  bool get isLocationTracking => _isLocationTracking;
  List<Pin> get nearbyPins => _nearbyPins;
  bool get isPinsLoading => _isPinsLoading;
  Pin? get selectedPin => _selectedPin;
  double get searchRadius => _searchRadius;
  bool get hasNetworkError => _hasNetworkError;
  String get errorMessage => _errorMessage;
  
  // Computed values
  LatLng get currentLatLng {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      // Default location if user position is unknown
      return const LatLng(
        AppConstants.defaultLatitude,
        AppConstants.defaultLongitude,
      );
    }
  }
  
  // Constructor
  MapProvider() {
    _initLocationTracking();
  }
  
  // Initialize map controller - will be implemented for Leaflet later
  void initMapController(MapController controller) {
    _mapController = controller;
    _isMapLoading = false;
    notifyListeners();
    
    // Initial camera move to user location
    if (_currentPosition != null) {
      animateToUserLocation();
    }
    
    // Load nearby pins
    _loadNearbyPins();
  }
  
  // Method for handling map creation from Flutter widget
  void onMapCreated(MapController controller) {
    initMapController(controller);
  }
  
  // Method for when the map style is loaded (placeholder for Leaflet)
  void onStyleLoaded() {
    // Will be implemented for Leaflet
    print('Map style loaded');
  }
  
  // Center the map on user's location
  void centerOnUserLocation() {
    animateToUserLocation();
  }
  
  // Initialize location tracking
  Future<void> _initLocationTracking() async {
    try {
      final permissionStatus = await _locationService.requestPermission();
      
      if (permissionStatus == LocationPermission.denied ||
          permissionStatus == LocationPermission.deniedForever) {
        // Handle permission denied
        return;
      }
      
      // Get current position
      _currentPosition = await _locationService.getCurrentPosition();
      notifyListeners();
      
      // Start position updates
      _isLocationTracking = true;
      _positionStream = _locationService.getPositionStream().listen(
        (Position position) {
          _currentPosition = position;
          
          // Update pins within range
          _updatePinsInRange();
          
          // If tracking is enabled, move camera
          if (_isLocationTracking && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(position.latitude, position.longitude),
              ),
            );
          }
          
          notifyListeners();
        },
        onError: (error) {
          print('Location stream error: $error');
          _isLocationTracking = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('Error initializing location: $e');
      _isLocationTracking = false;
      notifyListeners();
    }
  }
  
  // Toggle location tracking
  void toggleLocationTracking() {
    _isLocationTracking = !_isLocationTracking;
    
    if (_isLocationTracking && _currentPosition != null && _mapController != null) {
      animateToUserLocation();
    }
    
    notifyListeners();
  }
  
  // Animate camera to user location
  void animateToUserLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          _zoom,
        ),
      );
    }
  }
  
  // Update camera position values
  void updateCameraPosition(CameraPosition position) {
    _zoom = position.zoom;
    _bearing = position.bearing;
    _pitch = position.tilt;
    notifyListeners();
  }
  
  // Load nearby pins from API
  Future<void> _loadNearbyPins() async {
    if (_currentPosition == null) return;
    
    _isPinsLoading = true;
    _hasNetworkError = false;
    notifyListeners();
    
    try {
      final pins = await _pinsService.getNearbyPins(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );
      
      _nearbyPins = pins;
      _updatePinsInRange();
      
      _isPinsLoading = false;
      _hasNetworkError = false; // Clear any previous error state
      notifyListeners();
    } catch (e) {
      print('Error loading pins: $e');
      _isPinsLoading = false;
      
      // Check if this is a network error
      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') || 
                            errorString.contains('socket') ||
                            errorString.contains('connection') ||
                            errorString.contains('host lookup') ||
                            errorString.contains('dns');
      
      _hasNetworkError = true;
      _errorMessage = isNetworkError
          ? 'Network error. Please check your connection and try again.'
          : 'Failed to load pins. Please try again later.';
      
      notifyListeners();
      
      // Set up auto-retry if it's a network error
      if (isNetworkError && !_isAutoRetryScheduled) {
        _scheduleAutoRetry();
      }
    }
  }
  
  // Update which pins are within range of the user
  void _updatePinsInRange() {
    if (_currentPosition == null) return;
    
    for (final pin in _nearbyPins) {
      pin.isWithinRange = pin.isInRange(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );
    }
    
    notifyListeners();
  }
  
  // Select a pin
  void selectPin(Pin pin) {
    _selectedPin = pin;
    
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pin.latitude, pin.longitude),
          _zoom,
        ),
      );
    }
    
    notifyListeners();
  }
  
  // Clear selected pin
  void clearSelectedPin() {
    _selectedPin = null;
    notifyListeners();
  }
  
  // Change search radius
  void setSearchRadius(double radius) {
    _searchRadius = radius;
    _loadNearbyPins();
    notifyListeners();
  }
  
  // Refresh pins
  void refreshPins() {
    _hasNetworkError = false;
    _errorMessage = '';
    _loadNearbyPins();
  }
  
  // Create a new pin
  Future<bool> createPin({
    required String title,
    String? description,
    required int trackId,
    required String serviceType,
    String skinId = 'default',
    double? latitude,
    double? longitude,
    bool isPrivate = false,
  }) async {
    // Use current position if lat/long not provided
    final lat = latitude ?? _currentPosition?.latitude;
    final lng = longitude ?? _currentPosition?.longitude;
    
    if (lat == null || lng == null) {
      return false; // Can't create pin without location
    }
    
    try {
      final pin = await _pinsService.createPin(
        title: title,
        description: description,
        trackId: trackId,
        serviceType: serviceType,
        skinId: skinId,
        latitude: lat,
        longitude: lng,
        isPrivate: isPrivate,
      );
      
      if (pin != null) {
        // Add new pin to the list
        _nearbyPins.add(pin);
        _updatePinsInRange();
        
        // Select the new pin
        selectPin(pin);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error creating pin: $e');
      return false;
    }
  }
  
  // Delete a pin
  Future<bool> deletePin(int pinId) async {
    try {
      final success = await _pinsService.deletePin(pinId);
      
      if (success) {
        // Remove pin from list
        _nearbyPins.removeWhere((pin) => pin.id == pinId);
        
        // Clear selected pin if needed
        if (_selectedPin?.id == pinId) {
          clearSelectedPin();
        }
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting pin: $e');
      return false;
    }
  }
  
  // Collect a pin
  Future<bool> collectPin(int pinId) async {
    try {
      final success = await _pinsService.collectPin(pinId);
      
      if (success) {
        // Update pin in the list if needed
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error collecting pin: $e');
      return false;
    }
  }
  
  // Update screen coordinates for pins
  void updatePinScreenCoordinates() {
    if (_mapController == null) return;
    
    for (final pin in _nearbyPins) {
      final screenPoint = _mapController!.toScreenLocation(
        LatLng(pin.latitude, pin.longitude),
      );
      
      pin.screenX = screenPoint.x;
      pin.screenY = screenPoint.y;
    }
    
    notifyListeners();
  }
  
  // Add this method for auto-retry
  void _scheduleAutoRetry() {
    if (_isAutoRetryScheduled) return;
    
    _isAutoRetryScheduled = true;
    
    Future.delayed(const Duration(seconds: 30), () {
      _isAutoRetryScheduled = false;
      
      if (_hasNetworkError) {
        print('Auto-retrying pin loading after network error');
        refreshPins();
      }
    });
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
} 