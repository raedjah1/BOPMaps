import 'package:flutter/material.dart';
import '../models/pin.dart';
import '../services/api/pins_service.dart';

class PinProvider with ChangeNotifier {
  final PinsService _pinsService = PinsService();
  
  List<Pin> _pins = [];
  List<Pin> _userPins = [];
  List<Pin> _collectedPins = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<Pin> get pins => _pins;
  List<Pin> get userPins => _userPins;
  List<Pin> get collectedPins => _collectedPins;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Load all pins
  Future<void> loadAllPins() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // This is a placeholder until we implement the actual API call
      // In a real app, you would call _pinsService.getAllPins()
      await Future.delayed(const Duration(seconds: 1));
      _pins = []; // Would be populated with real data
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load pins: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Load user's pins
  Future<void> loadUserPins() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // This is a placeholder until we implement the actual API call
      // In a real app, you would call _pinsService.getUserPins()
      await Future.delayed(const Duration(seconds: 1));
      _userPins = []; // Would be populated with real data
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load user pins: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Load collected pins
  Future<void> loadCollectedPins() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // This is a placeholder until we implement the actual API call
      // In a real app, you would call _pinsService.getCollectedPins()
      await Future.delayed(const Duration(seconds: 1));
      _collectedPins = []; // Would be populated with real data
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load collected pins: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Create a new pin
  Future<bool> createPin({
    required String title,
    String? description,
    required int trackId,
    required String serviceType,
    required double latitude,
    required double longitude,
    bool isPrivate = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final pin = await _pinsService.createPin(
        title: title,
        description: description,
        trackId: trackId,
        serviceType: serviceType,
        latitude: latitude,
        longitude: longitude,
        isPrivate: isPrivate,
        skinId: 'default',
      );
      
      if (pin != null) {
        _pins.add(pin);
        _userPins.add(pin);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _isLoading = false;
      _errorMessage = 'Failed to create pin.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error creating pin: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Collect a pin
  Future<bool> collectPin(int pinId) async {
    try {
      final success = await _pinsService.collectPin(pinId);
      
      if (success) {
        // Find the pin in our lists
        final pin = _pins.firstWhere((p) => p.id == pinId);
        
        // Add to collected pins if not already there
        if (!_collectedPins.any((p) => p.id == pinId)) {
          _collectedPins.add(pin);
        }
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _errorMessage = 'Error collecting pin: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Delete a pin
  Future<bool> deletePin(int pinId) async {
    try {
      final success = await _pinsService.deletePin(pinId);
      
      if (success) {
        // Remove from all lists
        _pins.removeWhere((p) => p.id == pinId);
        _userPins.removeWhere((p) => p.id == pinId);
        _collectedPins.removeWhere((p) => p.id == pinId);
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _errorMessage = 'Error deleting pin: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
} 