import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:math';
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
          final mergedData = {...existingProfile, ...userData};
          userData = mergedData;
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

        // Get ALL profiles that match gender preference and age criteria
        // We'll handle distance filtering client-side
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
            .lte('age', filterMaxAge); // Max age filter

        // Ensure profiles have location data
        query = query.not('latitude', 'is', null).not('longitude', 'is', null);

        // Ensure profiles have required media
        query = query
            .not('profile_picture_url', 'is', null)
            .not('voice_bio_url', 'is', null);

        // Apply gender filter if not interested in everyone
        if (interestedIn != 'Everyone') {
          query = query.eq('gender', interestedIn);
        }

        // Execute the query to get all matching profiles
        final matchingProfiles = await query;

        print(
          'Found ${matchingProfiles.length} matching profiles before distance filtering',
        );

        // Convert to list of maps and filter by distance
        final List<Map<String, dynamic>> filteredProfiles = [];

        for (final profile in matchingProfiles) {
          final Map<String, dynamic> profileMap =
              profile as Map<String, dynamic>;
          final double? profileLat = profileMap['latitude'];
          final double? profileLng = profileMap['longitude'];

          if (profileLat != null && profileLng != null) {
            final double distance = _calculateDistance(
              userLat,
              userLng,
              profileLat,
              profileLng,
            );

            // Add distance to profile data
            profileMap['distance'] = distance.round();

            // Only include profiles within max distance
            if (distance <= filterMaxDistance) {
              filteredProfiles.add(profileMap);
            }
          }
        }

        print(
          'Found ${filteredProfiles.length} profiles after distance filtering',
        );

        // Sort by distance (closest first)
        filteredProfiles.sort((a, b) {
          final distanceA = a['distance'] as int;
          final distanceB = b['distance'] as int;
          return distanceA.compareTo(distanceB);
        });

        // Apply pagination
        final int endIndex = offset + limit;
        final int safeEndIndex =
            endIndex < filteredProfiles.length
                ? endIndex
                : filteredProfiles.length;

        List<Map<String, dynamic>> paginatedProfiles = [];
        if (offset < filteredProfiles.length) {
          paginatedProfiles = filteredProfiles.sublist(offset, safeEndIndex);
        }

        print(
          'Returning ${paginatedProfiles.length} profiles after pagination (offset: $offset, limit: $limit)',
        );

        return paginatedProfiles;
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
      print('Checking for match with profile ID: $swipedProfileId');

      // Check if the other user has already liked the current user
      final result = await _supabaseClient
          .from('swipes')
          .select()
          .eq('user_id', swipedProfileId)
          .eq('swiped_profile_id', currentUser!.id)
          .eq('liked', true)
          .limit(1);

      print(
        'Match check result: ${result.isNotEmpty ? "MATCH FOUND!" : "No match found"}',
      );

      // If there's a match, create a match record
      if (result.isNotEmpty) {
        await _createMatchRecord(swipedProfileId);
      }

      return result.isNotEmpty;
    } catch (e) {
      print('Error checking for match: $e');
      return false;
    }
  }

  // Create a match record in the matches table
  static Future<void> _createMatchRecord(String matchedProfileId) async {
    if (currentUser == null) return;

    try {
      print(
        'Creating match record between ${currentUser!.id} and $matchedProfileId',
      );

      // Check if match already exists to avoid duplicates
      final existingMatch = await _supabaseClient
          .from('matches')
          .select()
          .or('user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}')
          .or('user_id1.eq.$matchedProfileId,user_id2.eq.$matchedProfileId')
          .limit(1);

      if (existingMatch.isNotEmpty) {
        print(
          'Match already exists between ${currentUser!.id} and $matchedProfileId',
        );
        return;
      }

      // Create the match record - use .select() to return the inserted record
      // This ensures the real-time subscription is triggered
      final response =
          await _supabaseClient.from('matches').insert({
            'user_id1': currentUser!.id,
            'user_id2': matchedProfileId,
            'created_at': DateTime.now().toIso8601String(),
            'seen_by_user1':
                false, // Changed to false so both users need to see the match
            'seen_by_user2': false, // Other user hasn't seen it yet
          }).select();

      print('Match created with response: $response');

      // Add a small delay to ensure the real-time event is processed
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('Error creating match record: $e');
    }
  }

  // Subscribe to new matches for the current user
  static RealtimeChannel subscribeToMatches(
    Function(Map<String, dynamic>) onMatchCreated,
  ) {
    if (currentUser == null) {
      throw Exception('User must be logged in to subscribe to matches');
    }

    print(
      'Setting up real-time subscription for matches for user: ${currentUser!.id}',
    );

    // Create a channel for matches
    final channel = _supabaseClient.channel('matches_channel');

    // Set up the channel to listen for matches
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'matches',
      callback: (payload) async {
        print('New match event received: ${payload.toString()}');
        print('New match record: ${payload.newRecord}');

        // Check if this match involves the current user
        final Map<String, dynamic> newRecord = payload.newRecord;
        String? matchedProfileId;

        if (newRecord['user_id1'] == currentUser!.id) {
          // Current user is user1
          matchedProfileId = newRecord['user_id2'];
          print('Current user is user1, matched with user2: $matchedProfileId');
        } else if (newRecord['user_id2'] == currentUser!.id) {
          // Current user is user2
          matchedProfileId = newRecord['user_id1'];
          print('Current user is user2, matched with user1: $matchedProfileId');
        } else {
          print('Match does not involve current user: ${currentUser!.id}');
          return;
        }

        if (matchedProfileId != null) {
          print('Fetching profile details for matched user: $matchedProfileId');
          final matchedProfile = await getProfileById(matchedProfileId);

          if (matchedProfile != null) {
            print(
              'Calling onMatchCreated callback with profile: ${matchedProfile['name']}',
            );
            onMatchCreated({'match': newRecord, 'profile': matchedProfile});
          } else {
            print(
              'Failed to fetch profile for matched user: $matchedProfileId',
            );
          }
        }
      },
    );

    // Subscribe to the channel
    print('Subscribing to matches channel');
    channel.subscribe((status, error) {
      if (error != null) {
        print('Error subscribing to matches channel: $error');
      } else {
        print(
          'Successfully subscribed to matches channel with status: $status',
        );
      }
    });

    return channel;
  }

  // Get profile by ID
  static Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    return _safeApiCall(() async {
      try {
        final result =
            await _supabaseClient
                .from('profiles')
                .select()
                .eq('id', profileId)
                .limit(1)
                .single();

        return result;
      } catch (e) {
        print('Error getting profile by ID: $e');
        return null;
      }
    });
  }

  // Get all unseen matches for the current user
  static Future<List<Map<String, dynamic>>> getUnseenMatches() async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        print('Checking for unseen matches for user: ${currentUser!.id}');

        // Get matches where current user is user1 and hasn't seen the match
        final matchesAsUser1 = await _supabaseClient
            .from('matches')
            .select()
            .eq('user_id1', currentUser!.id)
            .eq('seen_by_user1', false);

        print('Unseen matches as user1: ${matchesAsUser1.length}');

        // Get matches where current user is user2 and hasn't seen the match
        final matchesAsUser2 = await _supabaseClient
            .from('matches')
            .select()
            .eq('user_id2', currentUser!.id)
            .eq('seen_by_user2', false);

        print('Unseen matches as user2: ${matchesAsUser2.length}');

        // Combine the results
        final List<Map<String, dynamic>> unseenMatches = [];

        // Process matches where user is user1
        for (final match in matchesAsUser1) {
          final matchedProfileId = match['user_id2'];
          final matchedProfile = await getProfileById(matchedProfileId);

          if (matchedProfile != null) {
            unseenMatches.add({'match': match, 'profile': matchedProfile});
          }
        }

        // Process matches where user is user2
        for (final match in matchesAsUser2) {
          final matchedProfileId = match['user_id1'];
          final matchedProfile = await getProfileById(matchedProfileId);

          if (matchedProfile != null) {
            unseenMatches.add({'match': match, 'profile': matchedProfile});
          }
        }

        print('Total unseen matches found: ${unseenMatches.length}');
        return unseenMatches;
      } catch (e) {
        print('Error getting unseen matches: $e');
        return [];
      }
    });
  }

  // Mark a match as seen by the current user - alternative approach that works with RLS
  static Future<void> markMatchAsSeen(String matchId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return;

      try {
        print('Marking match as seen: $matchId for user: ${currentUser!.id}');

        // Check if the current user is user1 or user2 in this match
        final match =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('Found match to mark as seen: $match');

        // Determine which field to update based on the user's role
        String fieldToUpdate;
        if (match['user_id1'] == currentUser!.id) {
          // Current user is user1
          fieldToUpdate = 'seen_by_user1';
          print('Current user is user1, updating $fieldToUpdate to true');
        } else if (match['user_id2'] == currentUser!.id) {
          // Current user is user2
          fieldToUpdate = 'seen_by_user2';
          print('Current user is user2, updating $fieldToUpdate to true');
        } else {
          print('Current user is neither user1 nor user2 in this match');
          return;
        }

        // Check if it's already marked as seen
        if (match[fieldToUpdate] == true) {
          print('Match is already marked as seen for this user');
          return;
        }

        // WORKAROUND: Since direct updates are blocked by RLS, we'll try a different approach
        try {
          print('Using alternative approach to mark match as seen');

          // Try to insert a record in the match_seen table using upsert to handle duplicates
          await _supabaseClient.from('match_seen').upsert({
            'match_id': matchId,
            'user_id': currentUser!.id,
            'seen_at': DateTime.now().toIso8601String(),
          }, onConflict: 'match_id,user_id');

          print('Successfully recorded match as seen in match_seen table');

          // For backward compatibility, still try to update the match
          // but don't throw an error if it fails
          try {
            await _supabaseClient
                .from('matches')
                .update({fieldToUpdate: true})
                .eq('id', matchId);
            print('Successfully updated match record directly');
          } catch (e) {
            print(
              'Could not update match directly due to RLS, but match_seen record was created: $e',
            );
            // This is expected to fail with RLS, so we don't rethrow
          }

          return;
        } catch (e) {
          print('Error with alternative approach: $e');
          throw e;
        }
      } catch (e) {
        print('Error marking match as seen: $e');
        throw e;
      }
    });
  }

  // Check if a match has been seen by the current user
  static Future<bool> hasMatchBeenSeen(String matchId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        // First check the match_seen table
        final seenRecords = await _supabaseClient
            .from('match_seen')
            .select()
            .eq('match_id', matchId)
            .eq('user_id', currentUser!.id)
            .limit(1);

        if (seenRecords.isNotEmpty) {
          return true;
        }

        // If no record in match_seen, check the matches table
        final match =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        if (match['user_id1'] == currentUser!.id) {
          return match['seen_by_user1'] == true;
        } else if (match['user_id2'] == currentUser!.id) {
          return match['seen_by_user2'] == true;
        }

        return false;
      } catch (e) {
        print('Error checking if match has been seen: $e');
        return false;
      }
    });
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

  // Manually check for matches with profiles the user has liked
  static Future<List<Map<String, dynamic>>> checkForManualMatches() async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        print('Manually checking for matches for user: ${currentUser!.id}');

        // Get profiles that the current user has liked
        final likedProfiles = await _supabaseClient
            .from('swipes')
            .select('swiped_profile_id')
            .eq('user_id', currentUser!.id)
            .eq('liked', true);

        print('User has liked ${likedProfiles.length} profiles');

        if (likedProfiles.isEmpty) return [];

        // Extract the IDs of liked profiles
        final List<String> likedProfileIds =
            likedProfiles
                .map((profile) => profile['swiped_profile_id'] as String)
                .toList();

        // Find profiles that have liked the current user back
        final mutualLikes = [];

        // Check each liked profile individually
        for (final likedId in likedProfileIds) {
          final likes = await _supabaseClient
              .from('swipes')
              .select()
              .eq('user_id', likedId)
              .eq('swiped_profile_id', currentUser!.id)
              .eq('liked', true);

          mutualLikes.addAll(likes);
        }

        print('Found ${mutualLikes.length} mutual likes');

        // Create match records for any mutual likes that don't already have a match
        final List<Map<String, dynamic>> newMatches = [];

        for (final like in mutualLikes) {
          final otherUserId = like['user_id'];

          // Check if a match already exists
          final existingMatch = await _supabaseClient
              .from('matches')
              .select()
              .or(
                'user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}',
              )
              .or('user_id1.eq.$otherUserId,user_id2.eq.$otherUserId')
              .limit(1);

          if (existingMatch.isEmpty) {
            print('Creating new match for mutual like with user: $otherUserId');

            // Create a new match record - use .select() to return the inserted record
            // This ensures the real-time subscription is triggered
            final response =
                await _supabaseClient.from('matches').insert({
                  'user_id1': currentUser!.id,
                  'user_id2': otherUserId,
                  'created_at': DateTime.now().toIso8601String(),
                  'seen_by_user1': false,
                  'seen_by_user2': false,
                }).select();

            if (response.isNotEmpty) {
              final matchedProfile = await getProfileById(otherUserId);
              if (matchedProfile != null) {
                newMatches.add({
                  'match': response[0],
                  'profile': matchedProfile,
                });

                // Add a small delay to ensure the real-time event is processed
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }
          } else {
            print(
              'Match already exists for mutual like with user: $otherUserId',
            );
          }
        }

        print('Created ${newMatches.length} new match records');
        return newMatches;
      } catch (e) {
        print('Error in manual match check: $e');
        return [];
      }
    });
  }

  // Get match record between current user and another user
  static Future<List<Map<String, dynamic>>> getMatchWithProfile(
    String otherUserId,
  ) async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        print(
          'Getting match record between ${currentUser!.id} and $otherUserId',
        );

        // Get the match record
        final matchRecords = await _supabaseClient
            .from('matches')
            .select()
            .or('user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}')
            .or('user_id1.eq.$otherUserId,user_id2.eq.$otherUserId')
            .limit(1);

        if (matchRecords.isEmpty) {
          print(
            'No match record found between ${currentUser!.id} and $otherUserId',
          );
          return [];
        }

        print('Found match record: ${matchRecords.first}');

        // Get the profile of the other user
        final otherProfile = await getProfileById(otherUserId);
        if (otherProfile == null) {
          print('Could not find profile for user: $otherUserId');
          return [];
        }

        // Return the match record and profile
        return [
          {'match': matchRecords.first, 'profile': otherProfile},
        ];
      } catch (e) {
        print('Error getting match with profile: $e');
        return [];
      }
    });
  }

  // For debugging: Create a test match to verify real-time events
  static Future<Map<String, dynamic>?> createTestMatch() async {
    return _safeApiCall(() async {
      if (currentUser == null) return null;

      try {
        print('Creating a test match for debugging real-time events');

        // First, find a random profile to match with
        final profiles = await _supabaseClient
            .from('profiles')
            .select()
            .neq('id', currentUser!.id)
            .limit(5);

        if (profiles.isEmpty) {
          print('No profiles found to create a test match');
          return null;
        }

        // Pick the first profile
        final testMatchUserId = profiles[0]['id'];
        print('Creating test match with user: $testMatchUserId');

        // Create a match record - use .select() to return the inserted record
        final response =
            await _supabaseClient.from('matches').insert({
              'user_id1': currentUser!.id,
              'user_id2': testMatchUserId,
              'created_at': DateTime.now().toIso8601String(),
              'seen_by_user1': false,
              'seen_by_user2': false,
            }).select();

        print('Test match created with response: $response');

        if (response.isNotEmpty) {
          return response[0];
        }

        return null;
      } catch (e) {
        print('Error creating test match: $e');
        return null;
      }
    });
  }

  // Check if the current user has liked a specific profile
  static Future<bool> hasLikedProfile(String profileId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print('Checking if current user has liked profile: $profileId');

        // Query the swipes table to see if the current user has liked this profile
        final result = await _supabaseClient
            .from('swipes')
            .select()
            .eq('user_id', currentUser!.id)
            .eq('swiped_profile_id', profileId)
            .eq('liked', true)
            .limit(1);

        final hasLiked = result.isNotEmpty;
        print(
          'Current user ${hasLiked ? "has" : "has not"} liked profile: $profileId',
        );

        return hasLiked;
      } catch (e) {
        print('Error checking if user has liked profile: $e');
        return false;
      }
    });
  }
}
