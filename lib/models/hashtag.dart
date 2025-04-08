class HashTag {
  final int id;
  final String name;
  final int usageCount;
  final DateTime createdAt;
  final bool isGenre;
  final bool isInterest;

  HashTag({
    required this.id,
    required this.name,
    required this.usageCount,
    required this.createdAt,
    this.isGenre = false,
    this.isInterest = true,
  });

  factory HashTag.fromJson(Map<String, dynamic> json) {
    return HashTag(
      id: json['id'],
      name: json['name'],
      usageCount: json['usage_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      isGenre: json['is_genre'] ?? false,
      isInterest: json['is_interest'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'usage_count': usageCount,
      'created_at': createdAt.toIso8601String(),
      'is_genre': isGenre,
      'is_interest': isInterest,
    };
  }

  // Helper method to create new hashtag
  static HashTag create(String tagName) {
    return HashTag(
      id: -1, // Will be assigned by server
      name: tagName.toLowerCase(),
      usageCount: 1,
      createdAt: DateTime.now(),
      isGenre: tagName.toLowerCase().contains('music') || 
               tagName.toLowerCase().contains('genre'),
      isInterest: true,
    );
  }
  
  // Format hashtag name for display
  String get displayName {
    // If the tag has spaces, keep it as is
    if (name.contains(' ')) return name;
    
    // Capitalize first letter
    return name.isNotEmpty 
        ? '${name[0].toUpperCase()}${name.substring(1)}'
        : '';
  }
  
  // Get hashtag with "#" prefix
  String get hashtagFormat => '#$name';
  
  // Compare hashtags (used for sorting)
  int compareByPopularity(HashTag other) {
    return other.usageCount.compareTo(usageCount); // Sort by descending usage
  }
  
  // Compare hashtags alphabetically
  int compareAlphabetically(HashTag other) {
    return name.compareTo(other.name);
  }
  
  // Check if this is a popular hashtag (arbitrary threshold)
  bool get isPopular => usageCount > 100;
} 