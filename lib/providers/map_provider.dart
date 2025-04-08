import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/constants.dart';
import '../models/pin.dart';
import '../services/api/pins_service.dart';
import '../services/location/location_service.dart';

class MapProvider with ChangeNotifier {
  final PinsService _pinsService = PinsService();
  final LocationService _locationService = LocationService();
  
  // User location
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  // Map state
  LatLng _currentCenter = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude
  );
  double _currentZoom = AppConstants.defaultZoom;
  bool _isMapLoading = true;
  bool _isLocationTracking = false;
  
  // Pins
  List<dynamic> _pins = [];  // Can be either Pin objects or Map<String, dynamic>
  bool _isPinsLoading = false;
  dynamic _selectedPin;
  double _searchRadius = AppConstants.pinDiscoveryRadius;
  
  // Error handling
  bool _hasNetworkError = false;
  String _errorMessage = '';
  
  // Getters
  Position? get currentPosition => _currentPosition;
  LatLng get currentCenter => _currentCenter;
  double get zoom => _currentZoom;
  bool get isMapLoading => _isMapLoading;
  bool get isLocationTracking => _isLocationTracking;
  List<dynamic> get pins => _pins;
  bool get isPinsLoading => _isPinsLoading;
  dynamic get selectedPin => _selectedPin;
  double get searchRadius => _searchRadius;
  bool get hasNetworkError => _hasNetworkError;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isMapLoading || _isPinsLoading;
  
  // Constructor
  MapProvider() {
    _initLocationTracking();
  }
  
  // Initialize location tracking
  Future<void> _initLocationTracking() async {
    try {
      final permissionStatus = await _locationService.requestPermission();
      
      if (permissionStatus == LocationPermission.denied ||
          permissionStatus == LocationPermission.deniedForever) {
        _setError('Location permission denied');
        return;
      }
      
      // Get current position
      final position = await _locationService.getCurrentPosition();
      _currentPosition = position;
      _currentCenter = LatLng(position.latitude, position.longitude);
      _isMapLoading = false;
      notifyListeners();
      
      // Start position updates
      _isLocationTracking = true;
      _positionStream = _locationService.getPositionStream().listen(
        (Position position) {
          _currentPosition = position;
          
          // If tracking is enabled, move camera
          if (_isLocationTracking) {
            _currentCenter = LatLng(position.latitude, position.longitude);
            notifyListeners();
          }
          
          // Update pins based on new location
          refreshPins();
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
          _isLocationTracking = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error initializing location: $e');
      _isLocationTracking = false;
      _setError('Error getting location: $e');
      notifyListeners();
    }
  }
  
  // Toggle location tracking
  void toggleLocationTracking() {
    _isLocationTracking = !_isLocationTracking;
    notifyListeners();
  }
  
  // Update viewport when map is moved
  void updateViewport({
    required double latitude,
    required double longitude,
    required double zoom,
  }) {
    _currentCenter = LatLng(latitude, longitude);
    _currentZoom = zoom;
    
    // Only refresh pins if the view changed significantly
    // This prevents too many API calls when panning/zooming
    final distance = const Distance().distance(
      _currentCenter,
      LatLng(
        _currentPosition?.latitude ?? AppConstants.defaultLatitude,
        _currentPosition?.longitude ?? AppConstants.defaultLongitude,
      ),
    );
    
    if (distance > _searchRadius / 2) {
      refreshPins();
    }
  }
  
  // Refresh pins from API
  Future<void> refreshPins() async {
    try {
      _isPinsLoading = true;
      notifyListeners();
      
      // For testing, create mock pins if no current position
      if (_currentPosition == null) {
        await _createMockPins();
        return;
      }
      
      // In a real implementation, you would call the API
      // final response = await _pinsService.getNearbyPins(
      //   latitude: _currentPosition!.latitude,
      //   longitude: _currentPosition!.longitude,
      //   radius: _searchRadius,
      // );
      
      // For development, create mock pins
      await _createMockPins();
      
    } catch (e) {
      _setError('Error loading pins: $e');
    } finally {
      _isPinsLoading = false;
      notifyListeners();
    }
  }
  
  // Helper to set error state
  void _setError(String message) {
    _hasNetworkError = true;
    _errorMessage = message;
    _isMapLoading = false;
    _isPinsLoading = false;
    notifyListeners();
  }
  
  // Create mock pins for testing
  Future<void> _createMockPins() async {
    // Create mock data for testing
    await Future.delayed(const Duration(milliseconds: 500));
    
    final lat = _currentPosition?.latitude ?? AppConstants.defaultLatitude;
    final lng = _currentPosition?.longitude ?? AppConstants.defaultLongitude;
    
    final List<Map<String, dynamic>> mockPins = [];
    
    // Create random pins around the current location
    for (int i = 0; i < 10; i++) {
      final latOffset = (0.01 * (i % 3 == 0 ? 1 : -1)) * (i / 10);
      final lngOffset = (0.01 * (i % 2 == 0 ? 1 : -1)) * (i / 10);
      
      mockPins.add({
        'id': i.toString(),
        'title': 'Mock Pin $i',
        'artist': 'Artist ${i % 3}',
        'track_url': 'https://example.com/track$i',
        'latitude': lat + latOffset,
        'longitude': lng + lngOffset,
        'rarity': _getRarityForIndex(i),
        'is_collected': i % 4 == 0,
      });
    }
    
    _pins = mockPins;
    _isPinsLoading = false;
    notifyListeners();
  }
  
  // Helper to get rarity based on index
  String _getRarityForIndex(int index) {
    switch (index % 5) {
      case 0:
        return 'Common';
      case 1:
        return 'Uncommon';
      case 2:
        return 'Rare';
      case 3:
        return 'Epic';
      case 4:
        return 'Legendary';
      default:
        return 'Common';
    }
  }
  
  // Set selected pin
  void selectPin(dynamic pin) {
    _selectedPin = pin;
    notifyListeners();
  }
  
  // Clear selected pin
  void clearSelectedPin() {
    _selectedPin = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
} 