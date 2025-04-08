import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';

class ApiClient {
  final String baseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConstants.baseApiUrl;
  
  // Helper method to get auth token
  Future<String?> _getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }
  
  // Helper to handle API errors
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final responseBody = utf8.decode(response.bodyBytes);
    
    if (statusCode >= 200 && statusCode < 300) {
      if (responseBody.isNotEmpty) {
        return json.decode(responseBody);
      }
      return {'success': true}; // Return default success object for empty responses
    } else {
      // Try to parse error message from response
      try {
        final errorData = json.decode(responseBody);
        final errorMessage = errorData['message'] ?? 'Unknown error';
        throw ApiException(statusCode, errorMessage);
      } catch (e) {
        if (e is ApiException) {
          throw e;
        } else {
          throw ApiException(statusCode, 'Failed to parse error response');
        }
      }
    }
  }
  
  // GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams,
    );
    
    // Add auth header if required
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.get(
        uri,
        headers: headers,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
  
  // POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    // Add auth header if required
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
  
  // PUT request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    // Add auth header if required
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.put(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
  
  // PATCH request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    // Add auth header if required
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.patch(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
  
  // DELETE request
  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    // Add auth header if required
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.delete(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
  
  // Multipart request for file uploads
  Future<dynamic> uploadFile(
    String endpoint, {
    required File file,
    required String fieldName,
    Map<String, String>? fields,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    // Add auth header if required
    Map<String, String> headers = {};
    
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        throw ApiException(401, 'Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      
      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
      ));
      
      // Add other fields if provided
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException(0, 'No internet connection');
    } catch (e) {
      if (e is ApiException) {
        throw e;
      } else {
        throw ApiException(500, 'Unknown error: $e');
      }
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException(this.statusCode, this.message);
  
  @override
  String toString() {
    return 'ApiException: $statusCode - $message';
  }
} 