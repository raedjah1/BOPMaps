import 'package:intl/intl.dart';

/// Utility class for formatting date/time values in a user-friendly way
class TimeFormatter {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');

  /// Formats a DateTime as a relative time string (e.g., "2 hours ago", "Yesterday", "Jul 15, 2023")
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // Within the last minute
    if (difference.inSeconds < 60) {
      return 'Just now';
    }
    
    // Within the last hour
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    
    // Within the last day
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    
    // Yesterday
    if (difference.inDays == 1) {
      return 'Yesterday';
    }
    
    // Within the last week
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    
    // More than a week ago
    return _dateFormat.format(dateTime);
  }

  /// Formats a DateTime as a standard date string (e.g., "Jul 15, 2023")
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  /// Formats a DateTime as a date and time string (e.g., "Jul 15, 2023 2:30 PM")
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Formats a duration in a user-friendly way (e.g. "2h 30m", "45m", "30s")
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes.remainder(60);
      return '${duration.inHours}h${minutes > 0 ? ' ${minutes}m' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Formats a file size in bytes to a human-readable string
  /// (e.g., "1.5 KB", "3.2 MB", "1.7 GB")
  static String formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    if (bytes <= 0) return '0 B';
    
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
  
  /// Helper method for logarithm calculation
  static double log(num x) => _log(x) / _ln10;
  
  static final double _ln10 = _log(10);
  static double _log(num x) => x.toDouble().logarithm;
}

/// Extension on double to calculate natural logarithm
extension on double {
  double get logarithm {
    if (this <= 0) throw ArgumentError('Logarithm of non-positive number is undefined');
    
    // Using Dart's built-in natural logarithm
    return logBase(e);
  }
  
  double logBase(double base) {
    return log(this) / log(base);
  }
  
  // Natural logarithm base (e)
  static const double e = 2.718281828459045;
}

/// Returns x raised to the power of y
double pow(num x, num y) {
  if (y == 0) return 1;
  if (y == 1) return x.toDouble();
  if (x == 0) return 0;
  
  // For integer powers, use multiplication
  if (y is int && y > 0) {
    double result = x.toDouble();
    for (int i = 1; i < y; i++) {
      result *= x;
    }
    return result;
  }
  
  // For other cases (including negative and fractional powers)
  // use the exponential identity: x^y = e^(y*ln(x))
  return exp(y * log(x));
}

/// Returns e raised to the power of x
double exp(num x) {
  const double e = 2.718281828459045;
  
  // Fast path for common cases
  if (x == 0) return 1;
  if (x == 1) return e;
  
  // For integer powers, use multiplication
  if (x is int && x > 0 && x < 20) {
    double result = e;
    for (int i = 1; i < x; i++) {
      result *= e;
    }
    return result;
  }
  
  // For other values, use the Taylor series approximation
  // e^x = 1 + x + x^2/2! + x^3/3! + ...
  double sum = 1.0;
  double term = 1.0;
  
  for (int i = 1; i < 20; i++) {  // 20 terms is usually sufficient for good precision
    term *= x / i;
    sum += term;
    
    // Break early if we've reached the limit of double precision
    if (term.abs() < 1e-15 * sum.abs()) break;
  }
  
  return sum;
} 