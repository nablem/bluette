import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:math';
import '../utils/network_error_handler.dart';
import 'connectivity_service.dart';

class SupabaseService {
  static final SupabaseClient _supabaseClient = Supabase.instance.client;

  // Get current user
  static User? get currentUser => _supabaseClient.auth.currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Wrapper for API calls to handle network errors consistently
  static Future<T> _safeApiCall<T>(Future<T> Function() apiCall) async {
    try {
      // Check for internet connection before making the call
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        throw SocketException('No internet connection');
      }

      return await apiCall();
    } catch (e) {
      // Log the error for debugging
      print('API call error: ${e.toString()}');

      // Rethrow with the original error to preserve stack trace
      throw e;
    }
  }

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    return _safeApiCall(() async {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );
      return response;
    });
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _safeApiCall(() async {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    });
  }

  // Sign out
  static Future<void> signOut() async {
    return _safeApiCall(() async {
      await _supabaseClient.auth.signOut();
    });
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    return _safeApiCall(() async {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    });
  }

  // Update user data
  static Future<void> updateUserData(Map<String, dynamic> userData) async {
    return _safeApiCall(() async {
      // Ensure required fields are never null
      final user = currentUser;
      if (user != null) {
        // Ensure email is never null
        if (!userData.containsKey('email') ||
            userData['email'] == null ||
            userData['email'].toString().isEmpty) {
          if (user.email != null && user.email!.isNotEmpty) {
            userData['email'] = user.email;
          } else {
            // Generate a placeholder email if somehow the user has no email
            userData['email'] =
                'user_${DateTime.now().millisecondsSinceEpoch}@example.com';
          }
        }

        // Ensure name is never null
        if (!userData.containsKey('name') ||
            userData['name'] == null ||
            userData['name'].toString().isEmpty) {
          // Try to get name from user metadata first
          if (user.userMetadata != null &&
              user.userMetadata!.containsKey('name') &&
              user.userMetadata!['name'] != null &&
              user.userMetadata!['name'].toString().isNotEmpty) {
            userData['name'] = user.userMetadata!['name'];
          }
          // Use email as fallback (without the domain part)
          else if (user.email != null && user.email!.isNotEmpty) {
            userData['name'] = user.email!.split('@')[0];
          }
          // Last resort fallback
          else {
            userData['name'] = 'User_${DateTime.now().millisecondsSinceEpoch}';
          }
        }
      }

      // First, try to get the current profile to see what's already there
      Map<String, dynamic>? existingProfile;
      if (currentUser != null) {
        try {
          existingProfile =
              await _supabaseClient
                  .from('profiles')
                  .select()
                  .eq('id', currentUser!.id)
                  .single();
          print('Existing profile before update: $existingProfile');

          // Ensure we have the id field in the userData
          userData['id'] = currentUser!.id;

          // Merge existing profile with new data to ensure we don't lose any fields
          if (existingProfile != null) {
            // Only update fields that are provided in userData
            // Keep all other fields from existingProfile
            final mergedData = {...existingProfile, ...userData};
            userData = mergedData;
          }
        } catch (e) {
          print('Error fetching existing profile: $e');
          // Ensure we have the id field in the userData
          userData['id'] = currentUser!.id;
        }
      }

      print('Updating profile with data: $userData');

      // Perform the upsert operation
      final response = await _supabaseClient
          .from('profiles')
          .upsert(userData, onConflict: 'id');

      print('Upsert response: $response');
      print('Profile updated successfully');

      // Verify the update by fetching the profile again
      if (currentUser != null) {
        final updatedProfile =
            await _supabaseClient
                .from('profiles')
                .select()
                .eq('id', currentUser!.id)
                .single();

        print('Verified profile after update: $updatedProfile');

        // Check if filter values were updated correctly
        if (userData.containsKey('min_age')) {
          print('Verified min_age after update: ${updatedProfile['min_age']}');
        }
        if (userData.containsKey('max_age')) {
          print('Verified max_age after update: ${updatedProfile['max_age']}');
        }
        if (userData.containsKey('max_distance')) {
          print(
            'Verified max_distance after update: ${updatedProfile['max_distance']}',
          );
        }

        // If the name in the database doesn't match what we tried to set,
        // try one more time with a more direct approach
        if (userData.containsKey('name') &&
            updatedProfile['name'] != userData['name']) {
          print('Name mismatch detected! Trying direct update...');

          // Try a direct update instead of upsert
          await _supabaseClient
              .from('profiles')
              .update({'name': userData['name']})
              .eq('id', currentUser!.id);

          // Verify again
          final finalCheck =
              await _supabaseClient
                  .from('profiles')
                  .select()
                  .eq('id', currentUser!.id)
                  .single();

          print('Final name check: ${finalCheck['name']}');
        }
      }
    });
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    return _safeApiCall(() async {
      if (currentUser == null) return null;

      final response =
          await _supabaseClient
              .from('profiles')
              .select()
              .eq('id', currentUser!.id)
              .single();

      return response;
    });
  }

  // Upload profile picture
  static Future<String?> uploadProfilePicture(File imageFile) async {
    return _safeApiCall(() async {
      if (currentUser == null) return null;

      final fileExt = path.extension(imageFile.path);
      final fileName = '${currentUser!.id}$fileExt';

      try {
        print('Uploading profile picture: $fileName');
        final response = await _supabaseClient.storage
            .from('profile_pictures')
            .upload(
              fileName,
              imageFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        if (response.isNotEmpty) {
          // Get a signed URL with a token that expires in 2 years (63072000 seconds)
          final imageUrl = _supabaseClient.storage
              .from('profile_pictures')
              .createSignedUrl(fileName, 63072000);

          print('Profile picture uploaded successfully, getting signed URL');

          // Update profile with the signed URL
          await updateUserData({
            'id': currentUser!.id,
            'profile_picture_url': await imageUrl,
          });

          return await imageUrl;
        }
      } catch (e) {
        print('Error uploading profile picture: $e');
        throw e;
      }

      return null;
    });
  }

  // Upload voice bio
  static Future<String?> uploadVoiceBio(File audioFile) async {
    if (currentUser == null) return null;

    final fileExt = path.extension(audioFile.path);
    final fileName = '${currentUser!.id}$fileExt';

    try {
      print('Uploading voice bio: $fileName');
      final response = await _supabaseClient.storage
          .from('voice_bios')
          .upload(
            fileName,
            audioFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      if (response.isNotEmpty) {
        // Get a signed URL with a token that expires in 2 years (63072000 seconds)
        final audioUrl = _supabaseClient.storage
            .from('voice_bios')
            .createSignedUrl(fileName, 63072000);

        print('Voice bio uploaded successfully, getting signed URL');

        // Get the actual URL after the Future completes
        final signedUrl = await audioUrl;
        print('Voice bio signed URL: $signedUrl');

        // Update profile with the signed URL
        await updateUserData({
          'id': currentUser!.id,
          'voice_bio_url': signedUrl,
        });

        return signedUrl;
      }
    } catch (e) {
      print('Error uploading voice bio: $e');
      throw e;
    }

    return null;
  }

  // Update location
  static Future<void> updateLocation(double latitude, double longitude) async {
    if (currentUser == null) return;

    await updateUserData({
      'id': currentUser!.id,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Delete user data
  static Future<void> deleteUserData() async {
    if (currentUser == null) return;

    try {
      // Delete profile data
      await _supabaseClient.from('profiles').delete().eq('id', currentUser!.id);

      // Delete storage files (profile picture and voice bio)
      try {
        await _supabaseClient.storage.from('profile_pictures').remove([
          currentUser!.id,
        ]);
      } catch (e) {
        print('Error deleting profile picture: $e');
      }

      try {
        await _supabaseClient.storage.from('voice_bios').remove([
          currentUser!.id,
        ]);
      } catch (e) {
        print('Error deleting voice bio: $e');
      }

      print('User data deleted successfully');
    } catch (e) {
      print('Error deleting user data: $e');
      throw e;
    }
  }

  // Stream of auth changes
  static Stream<AuthState> get onAuthStateChange =>
      _supabaseClient.auth.onAuthStateChange;

  // Refresh profile picture URL
  static Future<String?> refreshProfilePictureUrl() async {
    if (currentUser == null) return null;

    try {
      // Get the user profile to check if there's a profile picture
      final profile = await getUserProfile();
      if (profile == null || profile['profile_picture_url'] == null) {
        return null;
      }

      // Extract the file name from the existing URL
      final String existingUrl = profile['profile_picture_url'];
      print('Refreshing profile picture URL: $existingUrl');

      // Get the file extension from the existing URL
      final fileExt = path.extension(existingUrl.split('?').first);
      final fileName = '${currentUser!.id}$fileExt';

      // Create a new signed URL
      final newSignedUrl = await _supabaseClient.storage
          .from('profile_pictures')
          .createSignedUrl(fileName, 63072000); // 2 years

      print('New signed URL for profile picture: $newSignedUrl');

      // Update the profile with the new URL
      await updateUserData({
        'id': currentUser!.id,
        'profile_picture_url': newSignedUrl,
      });

      return newSignedUrl;
    } catch (e) {
      print('Error refreshing profile picture URL: $e');
      return null;
    }
  }

  // Refresh voice bio URL
  static Future<String?> refreshVoiceBioUrl() async {
    if (currentUser == null) return null;

    try {
      // Get the user profile to check if there's a voice bio
      final profile = await getUserProfile();
      if (profile == null || profile['voice_bio_url'] == null) {
        return null;
      }

      // Extract the file name from the existing URL
      final String existingUrl = profile['voice_bio_url'];
      print('Refreshing voice bio URL: $existingUrl');

      // Get the file extension from the existing URL
      final fileExt = path.extension(existingUrl.split('?').first);
      final fileName = '${currentUser!.id}$fileExt';

      // Create a new signed URL
      final newSignedUrl = await _supabaseClient.storage
          .from('voice_bios')
          .createSignedUrl(fileName, 63072000); // 2 years

      print('New signed URL for voice bio: $newSignedUrl');

      // Update the profile with the new URL
      await updateUserData({
        'id': currentUser!.id,
        'voice_bio_url': newSignedUrl,
      });

      return newSignedUrl;
    } catch (e) {
      print('Error refreshing voice bio URL: $e');
      return null;
    }
  }

  // Fetch profiles based on gender preference and filter settings
  static Future<List<Map<String, dynamic>>> getProfilesToSwipe({
    int? minAge,
    int? maxAge,
    int? maxDistance,
  }) async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        // Get current user profile to determine gender preference and default filters
        final userProfile = await getUserProfile();
        if (userProfile == null) return [];

        final String? interestedIn = userProfile['interested_in'];
        if (interestedIn == null) return [];

        // Use provided filter values or defaults from user profile
        final int filterMinAge = minAge ?? userProfile['min_age'] ?? 18;
        final int filterMaxAge = maxAge ?? userProfile['max_age'] ?? 100;
        final int filterMaxDistance =
            maxDistance ?? userProfile['max_distance'] ?? 5;

        // Get user's location
        final double? userLat = userProfile['latitude'];
        final double? userLng = userProfile['longitude'];

        // If user has no location, return empty list
        if (userLat == null || userLng == null) {
          print('User has no location data');
          return [];
        }

        // Get profiles that the user has already swiped on
        final swipedProfiles = await _supabaseClient
            .from('swipes')
            .select('swiped_profile_id')
            .eq('user_id', currentUser!.id);

        // Extract the IDs of swiped profiles
        final List<String> swipedProfileIds =
            swipedProfiles.isNotEmpty
                ? List<String>.from(
                  swipedProfiles.map((profile) => profile['swiped_profile_id']),
                )
                : [];

        print('User has already swiped on ${swipedProfileIds.length} profiles');

        // Get profiles that match gender preference
        List<dynamic> matchingProfiles;

        // Base query excluding current user and already swiped profiles
        var query = _supabaseClient
            .from('profiles')
            .select()
            .neq('id', currentUser!.id); // Exclude current user

        // Exclude already swiped profiles if there are any
        if (swipedProfileIds.isNotEmpty) {
          // Use 'not in' to exclude all swiped profile IDs
          query = query.not('id', 'in', swipedProfileIds);
        }

        // Apply age filters
        query = query
            .gte('age', filterMinAge) // Min age filter
            .lte('age', filterMaxAge) // Max age filter
            .not('latitude', 'is', null) // Must have location
            .not('longitude', 'is', null);

        // Apply gender filter if not interested in everyone
        if (interestedIn != 'Everyone') {
          query = query.eq('gender', interestedIn);
        }

        // Execute the query
        matchingProfiles = await query;

        print(
          'Found ${matchingProfiles.length} matching profiles before distance filtering',
        );

        // Convert to list of maps
        final List<Map<String, dynamic>> profiles =
            matchingProfiles
                .map((profile) => profile as Map<String, dynamic>)
                .toList();

        // Filter by distance (done client-side since Supabase doesn't support geospatial queries)
        final List<Map<String, dynamic>> filteredProfiles = [];
        for (final profile in profiles) {
          final double? profileLat = profile['latitude'];
          final double? profileLng = profile['longitude'];

          if (profileLat != null && profileLng != null) {
            final double distance = _calculateDistance(
              userLat,
              userLng,
              profileLat,
              profileLng,
            );

            // Add distance to profile data
            profile['distance'] = distance.round();

            // Only include profiles within max distance
            if (distance <= filterMaxDistance) {
              filteredProfiles.add(profile);
            }
          }
        }

        // Sort by distance (closest first)
        filteredProfiles.sort((a, b) {
          final distanceA = a['distance'] as int;
          final distanceB = b['distance'] as int;
          return distanceA.compareTo(distanceB);
        });

        print(
          'Returning ${filteredProfiles.length} profiles after distance filtering',
        );

        return filteredProfiles;
      } catch (e) {
        print('Error getting profiles to swipe: $e');
        throw e;
      }
    });
  }

  // Fetch profiles based on gender preference and filter settings with batch loading
  static Future<List<Map<String, dynamic>>> getProfilesToSwipeBatch({
    int? minAge,
    int? maxAge,
    int? maxDistance,
    required int limit,
    required int offset,
  }) async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        // Get current user profile to determine gender preference and default filters
        final userProfile = await getUserProfile();
        if (userProfile == null) return [];

        final String? interestedIn = userProfile['interested_in'];
        if (interestedIn == null) return [];

        // Use provided filter values or defaults from user profile
        final int filterMinAge = minAge ?? userProfile['min_age'] ?? 18;
        final int filterMaxAge = maxAge ?? userProfile['max_age'] ?? 100;
        final int filterMaxDistance =
            maxDistance ?? userProfile['max_distance'] ?? 5;

        // Get user's location
        final double? userLat = userProfile['latitude'];
        final double? userLng = userProfile['longitude'];

        // If user has no location, return empty list
        if (userLat == null || userLng == null) {
          print('User has no location data');
          return [];
        }

        // Get profiles that the user has already swiped on
        final swipedProfiles = await _supabaseClient
            .from('swipes')
            .select('swiped_profile_id')
            .eq('user_id', currentUser!.id);

        // Extract the IDs of swiped profiles
        final List<String> swipedProfileIds =
            swipedProfiles.isNotEmpty
                ? List<String>.from(
                  swipedProfiles.map((profile) => profile['swiped_profile_id']),
                )
                : [];

        print('User has already swiped on ${swipedProfileIds.length} profiles');

        // Get profiles that match gender preference
        List<dynamic> matchingProfiles;

        // Base query excluding current user and already swiped profiles
        var query = _supabaseClient
            .from('profiles')
            .select()
            .neq('id', currentUser!.id); // Exclude current user

        // Exclude already swiped profiles if there are any
        if (swipedProfileIds.isNotEmpty) {
          // Use 'not in' to exclude all swiped profile IDs
          query = query.not('id', 'in', swipedProfileIds);
        }

        // Apply age filters
        query = query
            .gte('age', filterMinAge) // Min age filter
            .lte('age', filterMaxAge) // Max age filter
            .not('latitude', 'is', null) // Must have location
            .not('longitude', 'is', null);

        // Apply gender filter if not interested in everyone
        if (interestedIn != 'Everyone') {
          query = query.eq('gender', interestedIn);
        }

        // Apply limit and offset for batch loading
        // First execute the query to get the filtered results
        matchingProfiles = await query;

        // Then apply pagination to the results in memory
        final int endIndex = offset + limit;
        final int safeEndIndex =
            endIndex < matchingProfiles.length
                ? endIndex
                : matchingProfiles.length;

        if (offset < matchingProfiles.length) {
          matchingProfiles = matchingProfiles.sublist(offset, safeEndIndex);
        } else {
          matchingProfiles = [];
        }

        print(
          'Found ${matchingProfiles.length} matching profiles in batch (offset: $offset, limit: $limit)',
        );

        // Convert to list of maps
        final List<Map<String, dynamic>> profiles =
            matchingProfiles
                .map((profile) => profile as Map<String, dynamic>)
                .toList();

        // Filter by distance (done client-side since Supabase doesn't support geospatial queries)
        final List<Map<String, dynamic>> filteredProfiles = [];
        for (final profile in profiles) {
          final double? profileLat = profile['latitude'];
          final double? profileLng = profile['longitude'];

          if (profileLat != null && profileLng != null) {
            final double distance = _calculateDistance(
              userLat,
              userLng,
              profileLat,
              profileLng,
            );

            // Add distance to profile data
            profile['distance'] = distance.round();

            // Only include profiles within max distance
            if (distance <= filterMaxDistance) {
              filteredProfiles.add(profile);
            }
          }
        }

        // Sort by distance (closest first)
        filteredProfiles.sort((a, b) {
          final distanceA = a['distance'] as int;
          final distanceB = b['distance'] as int;
          return distanceA.compareTo(distanceB);
        });

        print(
          'Returning ${filteredProfiles.length} profiles after distance filtering',
        );

        return filteredProfiles;
      } catch (e) {
        print('Error getting profiles to swipe in batch: $e');
        throw e;
      }
    });
  }

  // Calculate distance between two points using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // Record a swipe (like or dislike)
  static Future<void> recordSwipe({
    required String swipedProfileId,
    required bool liked,
  }) async {
    if (currentUser == null) return;

    try {
      await _supabaseClient.from('swipes').insert({
        'user_id': currentUser!.id,
        'swiped_profile_id': swipedProfileId,
        'liked': liked,
      });
      print('Swipe recorded: ${liked ? 'liked' : 'disliked'} $swipedProfileId');
    } catch (e) {
      print('Error recording swipe: $e');
      throw e;
    }
  }

  // Check if there's a match (both users liked each other)
  static Future<bool> checkForMatch(String swipedProfileId) async {
    if (currentUser == null) return false;

    try {
      // Check if the other user has already liked the current user
      final result = await _supabaseClient
          .from('swipes')
          .select()
          .eq('user_id', swipedProfileId)
          .eq('swiped_profile_id', currentUser!.id)
          .eq('liked', true)
          .limit(1);

      return result.isNotEmpty;
    } catch (e) {
      print('Error checking for match: $e');
      return false;
    }
  }

  // Clear all swipes for the current user (for testing purposes)
  static Future<void> clearUserSwipes() async {
    if (currentUser == null) return;

    try {
      await _supabaseClient
          .from('swipes')
          .delete()
          .eq('user_id', currentUser!.id);

      print('All swipes cleared for current user');
    } catch (e) {
      print('Error clearing swipes: $e');
      throw e;
    }
  }
}
