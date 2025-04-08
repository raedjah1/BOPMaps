import 'api_client.dart';
import '../../config/constants.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  
  // Register a new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/register',
        body: {
          'username': username,
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Login an existing user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/login',
        body: {
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Logout user
  Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/logout',
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Refresh authentication token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/refresh',
        body: {
          'refresh_token': refreshToken,
        },
        requiresAuth: false,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Get user profile
  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.usersEndpoint}/me',
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? username,
    String? bio,
    List<String>? favoriteGenres,
  }) async {
    try {
      // Create request body with non-null fields
      final Map<String, dynamic> body = {};
      if (username != null) body['username'] = username;
      if (bio != null) body['bio'] = bio;
      if (favoriteGenres != null) body['favorite_genres'] = favoriteGenres;
      
      final response = await _apiClient.patch(
        '${AppConstants.usersEndpoint}/me',
        body: body,
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Request password reset
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/reset-password',
        body: {
          'email': email,
        },
        requiresAuth: false,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Verify email
  Future<Map<String, dynamic>> verifyEmail(String token, String code) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.authEndpoint}/verify-email',
        body: {
          'code': code,
        },
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
  
  // Connect music service
  Future<Map<String, dynamic>> connectMusicService(
    String token,
    String service,
  ) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.usersEndpoint}/connect-music-service',
        body: {
          'service': service,
        },
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }
} 