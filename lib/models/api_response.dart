class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.statusCode,
  });

  // Helper method to check if error is network related
  bool get isNetworkError => 
    error == 'network_error' || 
    error == 'timeout' ||
    error?.toLowerCase().contains('network') == true ||
    error?.toLowerCase().contains('connect') == true ||
    error?.toLowerCase().contains('internet') == true;
    
  // Helper method to extract specific errors from data if available
  Map<String, dynamic> get fieldErrors {
    if (data != null && 
        data is Map && 
        data.containsKey('errors') && 
        data['errors'] is Map) {
      return Map<String, dynamic>.from(data['errors']);
    }
    return {};
  }
  
  // For user-friendly error messages
  String get userFriendlyMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    
    if (isNetworkError) {
      return 'Network error. Please check your connection and try again.';
    }
    
    if (statusCode == 401) {
      return 'Your session has expired. Please log in again.';
    }
    
    if (statusCode == 403) {
      return 'You don\'t have permission to access this resource.';
    }
    
    if (statusCode == 404) {
      return 'The requested resource could not be found.';
    }
    
    if (statusCode == 422) {
      return 'The data you submitted was invalid.';
    }
    
    if (statusCode == 500) {
      return 'An unexpected server error occurred. Please try again later.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
} 