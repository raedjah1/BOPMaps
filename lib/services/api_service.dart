import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/api_response.dart';

class ApiService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final http.Client _client = http.Client();
  
  // Retry configuration
  final int maxRetries;
  final Duration initialRetryDelay;
  
  ApiService({
    this.baseUrl = AppConstants.apiBaseUrl,
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(seconds: 1),
    Map<String, String>? headers,
  }) : defaultHeaders = headers ?? {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Add auth token to headers
  Map<String, String> _getHeaders(String? token) {
    final headers = Map<String, String>.from(defaultHeaders);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
  
  // Generic GET request with retry logic
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    String? token,
    bool requiresAuth = true,
  }) async {
    return _executeWithRetry(
      () => _performGet(endpoint, queryParams: queryParams, token: token, requiresAuth: requiresAuth)
    );
  }
  
  // Generic POST request with retry logic
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    bool requiresAuth = true,
  }) async {
    return _executeWithRetry(
      () => _performPost(endpoint, data: data, token: token, requiresAuth: requiresAuth)
    );
  }
  
  // Generic PATCH request with retry logic
  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    bool requiresAuth = true,
  }) async {
    return _executeWithRetry(
      () => _performPatch(endpoint, data: data, token: token, requiresAuth: requiresAuth)
    );
  }
  
  // Generic DELETE request with retry logic
  Future<ApiResponse> delete(
    String endpoint, {
    String? token,
    bool requiresAuth = true,
  }) async {
    return _executeWithRetry(
      () => _performDelete(endpoint, token: token, requiresAuth: requiresAuth)
    );
  }
  
  // Actual GET implementation
  Future<ApiResponse> _performGet(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    String? token,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );
      
      final response = await _client.get(
        uri,
        headers: _getHeaders(token),
      );
      
      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection',
        error: 'network_error',
      );
    } on TimeoutException {
      return ApiResponse(
        success: false,
        message: 'Request timed out',
        error: 'timeout',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unknown error occurred',
        error: e.toString(),
      );
    }
  }
  
  // Actual POST implementation
  Future<ApiResponse> _performPost(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final encodedData = jsonEncode(data ?? {});
      
      final response = await _client.post(
        uri,
        headers: _getHeaders(token),
        body: encodedData,
      );
      
      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection',
        error: 'network_error',
      );
    } on TimeoutException {
      return ApiResponse(
        success: false,
        message: 'Request timed out',
        error: 'timeout',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unknown error occurred',
        error: e.toString(),
      );
    }
  }
  
  // Actual PATCH implementation
  Future<ApiResponse> _performPatch(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final encodedData = jsonEncode(data ?? {});
      
      final response = await _client.patch(
        uri,
        headers: _getHeaders(token),
        body: encodedData,
      );
      
      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection',
        error: 'network_error',
      );
    } on TimeoutException {
      return ApiResponse(
        success: false,
        message: 'Request timed out',
        error: 'timeout',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unknown error occurred',
        error: e.toString(),
      );
    }
  }
  
  // Actual DELETE implementation
  Future<ApiResponse> _performDelete(
    String endpoint, {
    String? token,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final response = await _client.delete(
        uri,
        headers: _getHeaders(token),
      );
      
      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection',
        error: 'network_error',
      );
    } on TimeoutException {
      return ApiResponse(
        success: false,
        message: 'Request timed out',
        error: 'timeout',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unknown error occurred',
        error: e.toString(),
      );
    }
  }
  
  // Process HTTP response
  ApiResponse _processResponse(http.Response response) {
    try {
      final dynamic decodedBody = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: decodedBody,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          data: decodedBody,
          message: decodedBody['message'] ?? 'Request failed',
          error: decodedBody['error'] ?? 'api_error',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to process response',
        error: 'parse_error',
        statusCode: response.statusCode,
      );
    }
  }
  
  // Retry mechanism
  Future<ApiResponse> _executeWithRetry(
    Future<ApiResponse> Function() operation
  ) async {
    ApiResponse response;
    int attempts = 0;
    Duration delay = initialRetryDelay;
    
    while (true) {
      response = await operation();
      attempts++;
      
      // No need to retry on success or non-network errors
      if (response.success || 
          (response.error != 'network_error' && 
           response.error != 'timeout') || 
          attempts >= maxRetries) {
        break;
      }
      
      // Wait before retry with exponential backoff
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
    
    return response;
  }
  
  // Close the client when done
  void dispose() {
    _client.close();
  }
} 