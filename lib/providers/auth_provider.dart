import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../services/api/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  User? _currentUser;
  String? _token;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Constructor
  AuthProvider() {
    _loadStoredCredentials();
  }
  
  // Load stored token and user data on app start
  Future<void> _loadStoredCredentials() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Load auth token
      _token = await _secureStorage.read(key: AppConstants.tokenKey);
      _refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      
      // If token exists, try to load user data
      if (_token != null) {
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString('user_data');
        
        if (userData != null) {
          _currentUser = User.fromJson(json.decode(userData));
        } else {
          // If we have a token but no stored user data, fetch it from API
          await _fetchUserProfile();
        }
      }
    } catch (e) {
      _error = 'Error loading credentials: $e';
      print(_error);
      await logout(); // Clear invalid credentials
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Register a new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.register(
        username: username,
        email: email,
        password: password,
      );
      
      if (response.containsKey('token')) {
        // Store token
        _token = response['token'];
        _refreshToken = response['refresh_token'];
        
        await _secureStorage.write(key: AppConstants.tokenKey, value: _token);
        await _secureStorage.write(key: AppConstants.refreshTokenKey, value: _refreshToken);
        
        // Get user profile
        await _fetchUserProfile();
        
        // Store user data in preferences
        await _storeUserData();
        
        return true;
      } else {
        _error = response['message'] ?? 'Registration failed';
        return false;
      }
    } catch (e) {
      _error = 'Registration error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Login existing user
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      
      if (response.containsKey('token')) {
        // Store token
        _token = response['token'];
        _refreshToken = response['refresh_token'];
        
        await _secureStorage.write(key: AppConstants.tokenKey, value: _token);
        await _secureStorage.write(key: AppConstants.refreshTokenKey, value: _refreshToken);
        
        // Get user profile
        await _fetchUserProfile();
        
        // Store user data in preferences
        await _storeUserData();
        
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      _error = 'Login error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Call logout API (to invalidate token on server)
      if (_token != null) {
        await _authService.logout(_token!);
      }
    } catch (e) {
      print('Logout API error: $e');
      // Continue with local logout regardless of API error
    }
    
    // Clear stored data
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    
    // Clear in-memory data
    _token = null;
    _refreshToken = null;
    _currentUser = null;
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Mock login for testing and development
  Future<bool> simulateLogin({
    required String userId,
    required String name,
    required String email,
    String? profilePic,
    String bio = 'Simulated login user',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Simulate a slight delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Create a mock user for testing
      _currentUser = User(
        id: int.tryParse(userId) ?? 1,
        username: name,
        email: email,
        isVerified: true,
        profilePicUrl: profilePic,
        bio: bio,
        createdAt: DateTime.now(),
        favoriteGenres: ['Pop', 'Rock', 'Hip-Hop'],
        connectedServices: {'spotify': true},
      );
      
      // Set a mock token
      _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      _refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store the mock data
      await _secureStorage.write(key: AppConstants.tokenKey, value: _token);
      await _secureStorage.write(key: AppConstants.refreshTokenKey, value: _refreshToken);
      await _storeUserData();
      
      return true;
    } catch (e) {
      _error = 'Simulated login error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // This is a mock implementation since we're not actually connecting to Google
      // In a real app, we would use the GoogleSignIn package to authenticate
      
      // Simulate a successful login
      await Future.delayed(const Duration(seconds: 1));
      
      // Create a mock user for testing
      _currentUser = User(
        id: 1,
        username: 'googleuser',
        email: 'google@example.com',
        isVerified: true,
        profilePicUrl: null,
        bio: 'Logged in with Google',
        createdAt: DateTime.now(),
        favoriteGenres: ['Pop', 'Rock'],
        connectedServices: {'spotify': true},
      );
      
      // Set a mock token
      _token = 'mock_google_token';
      _refreshToken = 'mock_google_refresh_token';
      
      // Store the mock data
      await _secureStorage.write(key: AppConstants.tokenKey, value: _token);
      await _secureStorage.write(key: AppConstants.refreshTokenKey, value: _refreshToken);
      await _storeUserData();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Google sign-in error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Fetch user profile from API
  Future<void> _fetchUserProfile() async {
    if (_token == null) return;
    
    try {
      final response = await _authService.getUserProfile(_token!);
      
      if (response.containsKey('id')) {
        _currentUser = User.fromJson(response);
        await _storeUserData();
      } else {
        throw Exception('Failed to fetch user profile');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      // If we get a 401 error, token might be expired
      if (e.toString().contains('401')) {
        await _refreshAuthToken();
      }
    }
  }
  
  // Store user data in SharedPreferences
  Future<void> _storeUserData() async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(_currentUser!.toJson()));
  }
  
  // Refresh authentication token
  Future<bool> _refreshAuthToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await _authService.refreshToken(_refreshToken!);
      
      if (response.containsKey('token')) {
        _token = response['token'];
        _refreshToken = response['refresh_token'];
        
        await _secureStorage.write(key: AppConstants.tokenKey, value: _token);
        await _secureStorage.write(
            key: AppConstants.refreshTokenKey, value: _refreshToken);
        
        return true;
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      // If refresh fails, force logout
      await logout();
      return false;
    }
  }
  
  // Update user profile
  Future<bool> updateProfile({
    String? username,
    String? bio,
    List<String>? favoriteGenres,
  }) async {
    if (_token == null || _currentUser == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.updateProfile(
        token: _token!,
        username: username,
        bio: bio,
        favoriteGenres: favoriteGenres,
      );
      
      if (response.containsKey('id')) {
        _currentUser = User.fromJson(response);
        await _storeUserData();
        return true;
      } else {
        _error = response['message'] ?? 'Profile update failed';
        return false;
      }
    } catch (e) {
      _error = 'Profile update error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      
      if (response['success'] == true) {
        return true;
      } else {
        _error = response['message'] ?? 'Password change failed';
        return false;
      }
    } catch (e) {
      _error = 'Password change error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.requestPasswordReset(email);
      
      if (response['success'] == true) {
        return true;
      } else {
        _error = response['message'] ?? 'Password reset request failed';
        return false;
      }
    } catch (e) {
      _error = 'Password reset request error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Verify email
  Future<bool> verifyEmail(String code) async {
    if (_token == null || _currentUser == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.verifyEmail(_token!, code);
      
      if (response['success'] == true) {
        // Update user verified status
        _currentUser = _currentUser!.copyWith(isVerified: true);
        await _storeUserData();
        return true;
      } else {
        _error = response['message'] ?? 'Email verification failed';
        return false;
      }
    } catch (e) {
      _error = 'Email verification error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Connect music service
  Future<bool> connectMusicService(String service) async {
    if (_token == null || _currentUser == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _authService.connectMusicService(_token!, service);
      
      if (response['success'] == true) {
        // Update connected services
        Map<String, bool> updatedServices = Map.from(_currentUser!.connectedServices);
        updatedServices[service] = true;
        
        _currentUser = _currentUser!.copyWith(connectedServices: updatedServices);
        await _storeUserData();
        return true;
      } else {
        _error = response['message'] ?? 'Music service connection failed';
        return false;
      }
    } catch (e) {
      _error = 'Music service connection error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper to get authorization header for API requests
  Map<String, String> get authHeaders {
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }
} 