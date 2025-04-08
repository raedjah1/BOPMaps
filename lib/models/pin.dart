import 'package:flutter/material.dart';
import 'user.dart';
import 'music_track.dart';

enum PinRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class Pin {
  final int id;
  final User owner;
  final double latitude;
  final double longitude;
  final String title;
  final String? description;
  final MusicTrack track;
  final String serviceType; // 'spotify', 'apple', 'soundcloud'
  final String skinId;
  final PinRarity rarity;
  final double auraRadius; // in meters
  final bool isPrivate;
  final DateTime? expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // UI helper properties (not from API)
  double? screenX;
  double? screenY;
  bool isWithinRange = false;

  Pin({
    required this.id,
    required this.owner,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.description,
    required this.track,
    required this.serviceType,
    required this.skinId,
    required this.rarity,
    required this.auraRadius,
    required this.isPrivate,
    this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
    this.screenX,
    this.screenY,
  });

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'],
      owner: User.fromJson(json['owner']),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      title: json['title'],
      description: json['description'],
      track: MusicTrack.fromJson(json['track']),
      serviceType: json['service_type'],
      skinId: json['skin_id'],
      rarity: _parseRarity(json['rarity']),
      auraRadius: json['aura_radius'].toDouble(),
      isPrivate: json['is_private'],
      expirationDate: json['expiration_date'] != null 
          ? DateTime.parse(json['expiration_date']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner.toJson(),
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'track': track.toJson(),
      'service_type': serviceType,
      'skin_id': skinId,
      'rarity': rarity.toString().split('.').last,
      'aura_radius': auraRadius,
      'is_private': isPrivate,
      'expiration_date': expirationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  // Helper method to create a new pin (for creating pins)
  static Pin createNew({
    required User owner,
    required double latitude,
    required double longitude,
    required String title,
    String? description,
    required MusicTrack track,
    required String serviceType,
    String skinId = 'default',
    PinRarity rarity = PinRarity.common,
    double auraRadius = 50.0,
    bool isPrivate = false,
    DateTime? expirationDate,
  }) {
    final now = DateTime.now();
    return Pin(
      id: -1, // Will be assigned by server
      owner: owner,
      latitude: latitude,
      longitude: longitude,
      title: title,
      description: description,
      track: track,
      serviceType: serviceType,
      skinId: skinId,
      rarity: rarity,
      auraRadius: auraRadius,
      isPrivate: isPrivate,
      expirationDate: expirationDate,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  // Calculate distance from a location (in meters)
  double distanceFrom(double lat, double lng) {
    // Simple Haversine distance calculation
    const int earthRadius = 6371000; // in meters
    final double lat1Rad = latitude * (pi / 180);
    final double lat2Rad = lat * (pi / 180);
    final double dLat = (lat - latitude) * (pi / 180);
    final double dLng = (lng - longitude) * (pi / 180);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  // Check if pin is within range from a point
  bool isInRange(double lat, double lng, double rangeMeters) {
    return distanceFrom(lat, lng) <= rangeMeters;
  }
  
  // Check if pin has expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }
  
  // Parse rarity from string
  static PinRarity _parseRarity(String rarityStr) {
    switch (rarityStr.toLowerCase()) {
      case 'common':
        return PinRarity.common;
      case 'uncommon':
        return PinRarity.uncommon;
      case 'rare':
        return PinRarity.rare;
      case 'epic':
        return PinRarity.epic;
      case 'legendary':
        return PinRarity.legendary;
      default:
        return PinRarity.common;
    }
  }
}

// Import PI and math functions
const double pi = 3.1415926535897932;
double sin(double x) => _math_sin(x);
double cos(double x) => _math_cos(x);
double sqrt(double x) => _math_sqrt(x);
double atan2(double y, double x) => _math_atan2(y, x);

// Dummy math functions (replace with dart:math)
double _math_sin(double x) => x; // Placeholder
double _math_cos(double x) => x; // Placeholder
double _math_sqrt(double x) => x; // Placeholder
double _math_atan2(double y, double x) => 0; // Placeholder 