import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../config/constants.dart';

class LocationService {
  // Request location permission
  Future<LocationPermission> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return Future.error('Location services are disabled');
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission still denied
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return Future.error(
          'Location permissions are permanently denied, cannot request permissions');
    }

    return permission;
  }

  // Get current position
  Future<Position> getCurrentPosition() async {
    final permission = await requestPermission();
    
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission not granted');
    }
    
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Stream position updates
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    const defaultLocationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Minimum distance (in meters) before updates
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings ?? defaultLocationSettings
    );
  }

  // Calculate distance between two coordinates
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Check if user is within range of a location
  bool isInRange(
    double userLat,
    double userLng,
    double targetLat,
    double targetLng,
    double rangeInMeters,
  ) {
    final distance = calculateDistance(
      userLat,
      userLng,
      targetLat,
      targetLng,
    );
    
    return distance <= rangeInMeters;
  }
  
  // Get default location
  Position getDefaultPosition() {
    return Position(
      latitude: AppConstants.defaultLatitude,
      longitude: AppConstants.defaultLongitude,
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: DateTime.now(),
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
  
  // Get all pins within a certain radius from a location
  List<Map<String, dynamic>> getPinsInRadius(
    List<Map<String, dynamic>> pins,
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    return pins.where((pin) {
      final double pinLat = pin['latitude'];
      final double pinLng = pin['longitude'];
      final distance = calculateDistance(
        latitude,
        longitude,
        pinLat,
        pinLng,
      );
      return distance <= radiusInMeters;
    }).toList();
  }
} 