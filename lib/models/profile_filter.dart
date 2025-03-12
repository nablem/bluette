class ProfileFilter {
  int minAge;
  int maxAge;
  int maxDistance;

  ProfileFilter({
    required this.minAge,
    required this.maxAge,
    required this.maxDistance,
  });

  // Create a copy of the filter with optional new values
  ProfileFilter copyWith({int? minAge, int? maxAge, int? maxDistance}) {
    return ProfileFilter(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistance: maxDistance ?? this.maxDistance,
    );
  }

  // Convert to a map for API requests
  Map<String, dynamic> toMap() {
    return {'min_age': minAge, 'max_age': maxAge, 'max_distance': maxDistance};
  }

  // Create from a map (e.g., from API response)
  factory ProfileFilter.fromMap(Map<String, dynamic> map) {
    return ProfileFilter(
      minAge: map['min_age'] ?? 18,
      maxAge: map['max_age'] ?? 100,
      maxDistance: map['max_distance'] ?? 5,
    );
  }

  // Default filter values
  factory ProfileFilter.defaultFilter({int? userAge}) {
    if (userAge != null) {
      // Calculate based on user's age
      final int minAge = (userAge - 5) < 18 ? 18 : (userAge - 5);
      final int maxAge = userAge + 5;
      return ProfileFilter(minAge: minAge, maxAge: maxAge, maxDistance: 5);
    } else {
      // Generic defaults if no user age provided
      return ProfileFilter(minAge: 18, maxAge: 100, maxDistance: 5);
    }
  }
}
