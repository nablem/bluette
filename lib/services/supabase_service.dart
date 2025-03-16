import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:math';
import 'connectivity_service.dart';
import 'package:flutter/material.dart';

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

        // Get current time for upcoming meetup check
        final now = DateTime.now();

        // Get all profiles with upcoming meetups to exclude them
        final profilesWithMeetups = await _supabaseClient
            .from('matches')
            .select('user_id1, user_id2')
            .not('meetup_time', 'is', null)
            .eq('is_cancelled', false)
            .eq('is_meetup_passed', false)
            .gt('meetup_time', now.toIso8601String());

        // Create a set of profile IDs with upcoming meetups
        final Set<String> profileIdsWithMeetups = {};
        for (final match in profilesWithMeetups) {
          profileIdsWithMeetups.add(match['user_id1']);
          profileIdsWithMeetups.add(match['user_id2']);
        }

        print(
          'Found ${profileIdsWithMeetups.length} profiles with upcoming meetups to exclude',
        );

        // Filter out profiles with upcoming meetups
        final List<Map<String, dynamic>> profilesWithoutMeetups =
            filteredProfiles
                .where(
                  (profile) => !profileIdsWithMeetups.contains(profile['id']),
                )
                .toList();

        print(
          'Found ${profilesWithoutMeetups.length} profiles after excluding those with upcoming meetups',
        );

        // Sort by distance (closest first)
        profilesWithoutMeetups.sort((a, b) {
          final distanceA = a['distance'] as int;
          final distanceB = b['distance'] as int;
          return distanceA.compareTo(distanceB);
        });

        print(
          'Returning ${profilesWithoutMeetups.length} profiles after distance filtering',
        );

        return profilesWithoutMeetups;
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
          final Map<String, dynamic> profileMap = profile;
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

        // Get current time for upcoming meetup check
        final now = DateTime.now();

        // Get all profiles with upcoming meetups to exclude them
        final profilesWithMeetups = await _supabaseClient
            .from('matches')
            .select('user_id1, user_id2')
            .not('meetup_time', 'is', null)
            .eq('is_cancelled', false)
            .eq('is_meetup_passed', false)
            .gt('meetup_time', now.toIso8601String());

        // Create a set of profile IDs with upcoming meetups
        final Set<String> profileIdsWithMeetups = {};
        for (final match in profilesWithMeetups) {
          profileIdsWithMeetups.add(match['user_id1']);
          profileIdsWithMeetups.add(match['user_id2']);
        }

        print(
          'Found ${profileIdsWithMeetups.length} profiles with upcoming meetups to exclude',
        );

        // Filter out profiles with upcoming meetups
        final List<Map<String, dynamic>> profilesWithoutMeetups =
            filteredProfiles
                .where(
                  (profile) => !profileIdsWithMeetups.contains(profile['id']),
                )
                .toList();

        print(
          'Found ${profilesWithoutMeetups.length} profiles after excluding those with upcoming meetups',
        );

        // Sort by distance (closest first)
        profilesWithoutMeetups.sort((a, b) {
          final distanceA = a['distance'] as int;
          final distanceB = b['distance'] as int;
          return distanceA.compareTo(distanceB);
        });

        // Apply pagination
        final int endIndex = offset + limit;
        final int safeEndIndex =
            endIndex < profilesWithoutMeetups.length
                ? endIndex
                : profilesWithoutMeetups.length;

        List<Map<String, dynamic>> paginatedProfiles = [];
        if (offset < profilesWithoutMeetups.length) {
          paginatedProfiles = profilesWithoutMeetups.sublist(
            offset,
            safeEndIndex,
          );
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
      // Check if the swiped profile has an uncancelled upcoming meetup
      final hasUpcomingMeetup = await hasProfileUpcomingMeetup(swipedProfileId);
      if (hasUpcomingMeetup) {
        print(
          'Profile $swipedProfileId has an upcoming meetup, skipping swipe',
        );
        return;
      }

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

  // Check if a profile has an uncancelled upcoming meetup
  static Future<bool> hasProfileUpcomingMeetup(String profileId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print('Checking if profile $profileId has an upcoming meetup');

        // Get current time
        final now = DateTime.now();

        // Query matches where the profile is either user1 or user2
        // and there's a scheduled meetup in the future
        // and the meetup is not cancelled
        final matches = await _supabaseClient
            .from('matches')
            .select()
            .or('user_id1.eq.$profileId,user_id2.eq.$profileId')
            .not('meetup_time', 'is', null)
            .eq('is_cancelled', false)
            .eq('is_meetup_passed', false)
            .gt('meetup_time', now.toIso8601String())
            .limit(1);

        final hasUpcomingMeetup = matches.isNotEmpty;
        print(
          'Profile $profileId ${hasUpcomingMeetup ? "has" : "does not have"} an upcoming meetup',
        );

        return hasUpcomingMeetup;
      } catch (e) {
        print('Error checking if profile has upcoming meetup: $e');
        return false;
      }
    });
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

  // Find a suitable place for a meetup between two users
  static Future<Map<String, dynamic>?> findSuitablePlaceForMeetup(
    String otherUserId,
  ) async {
    return _safeApiCall(() async {
      if (currentUser == null) return null;

      try {
        print('Finding suitable place for meetup with user: $otherUserId');

        // Get both user profiles to access their locations and availability
        final currentUserProfile = await getUserProfile();
        final otherUserProfile = await getProfileById(otherUserId);

        if (currentUserProfile == null || otherUserProfile == null) {
          print('Could not retrieve user profiles');
          return null;
        }

        // Get locations of both users
        final double? currentUserLat = currentUserProfile['latitude'];
        final double? currentUserLng = currentUserProfile['longitude'];
        final double? otherUserLat = otherUserProfile['latitude'];
        final double? otherUserLng = otherUserProfile['longitude'];

        if (currentUserLat == null ||
            currentUserLng == null ||
            otherUserLat == null ||
            otherUserLng == null) {
          print('One or both users do not have location data');
          return null;
        }

        // Calculate midpoint between the two users
        final midpointLat = (currentUserLat + otherUserLat) / 2;
        final midpointLng = (currentUserLng + otherUserLng) / 2;

        print('Midpoint location: $midpointLat, $midpointLng');

        // Get user availabilities
        final Map<String, dynamic>? currentUserAvailability =
            currentUserProfile['availability'];
        final Map<String, dynamic>? otherUserAvailability =
            otherUserProfile['availability'];

        if (currentUserAvailability == null || otherUserAvailability == null) {
          print(
            'One or both users do not have availability data, using defaults',
          );
          // Continue anyway, as we'll use default availability
        }

        // Try with a larger search radius first
        int searchRadius = 30; // Start with 30 km radius
        List<dynamic> places = [];

        // Try with increasingly larger search radius until we find at least one place
        while (places.isEmpty && searchRadius <= 100) {
          print('Searching for places within $searchRadius km of midpoint');

          // Query places table to find places near the midpoint
          places = await _supabaseClient.rpc(
            'find_places_near_point',
            params: {
              'lat': midpointLat,
              'lng': midpointLng,
              'max_distance': searchRadius,
              'limit_count': 20, // Get top 20 places
            },
          );

          if (places.isEmpty) {
            searchRadius += 20; // Increase search radius by 20 km
          }
        }

        if (places.isEmpty) {
          print(
            'No places found near midpoint even with expanded search radius',
          );

          // As a fallback, try to find places near the current user
          print('Trying to find places near the current user as fallback');
          places = await _supabaseClient.rpc(
            'find_places_near_point',
            params: {
              'lat': currentUserLat,
              'lng': currentUserLng,
              'max_distance': 50, // 50 km radius around current user
              'limit_count': 10, // Get top 10 places
            },
          );

          if (places.isEmpty) {
            print('No places found near current user either');
            return null;
          }

          print('Found ${places.length} places near current user as fallback');
        } else {
          print(
            'Found ${places.length} places near midpoint with radius $searchRadius km',
          );
        }

        // Get current date and time
        final now = DateTime.now();

        // Calculate the valid time range for meetups (20-72 hours from now)
        final earliestMeetupTime = now.add(const Duration(hours: 20));
        final latestMeetupTime = now.add(const Duration(hours: 72));

        print(
          'Valid meetup time range: ${earliestMeetupTime.toIso8601String()} to ${latestMeetupTime.toIso8601String()}',
        );

        // Find a suitable place and time based on availability
        List<Map<String, dynamic>> placesWithAvailability = [];

        for (final place in places) {
          final Map<String, dynamic>? placeAvailability = place['availability'];

          if (placeAvailability == null) {
            print('Place has no availability data: ${place['name']}, skipping');
            continue;
          }

          // Try to find a suitable time slot
          final DateTime? meetupTime = _findSuitableTimeSlotWithinRange(
            placeAvailability,
            currentUserAvailability,
            otherUserAvailability,
            earliestMeetupTime,
            latestMeetupTime,
          );

          if (meetupTime != null) {
            print(
              'Found suitable place and time: ${place['name']} at ${meetupTime.toIso8601String()}',
            );
            placesWithAvailability.add({
              'place': place,
              'meetup_time': meetupTime.toIso8601String(),
            });
          }
        }

        // Sort places by distance from midpoint
        placesWithAvailability.sort((a, b) {
          final placeA = a['place'];
          final placeB = b['place'];

          final distanceA = _calculateDistance(
            midpointLat,
            midpointLng,
            placeA['latitude'],
            placeA['longitude'],
          );

          final distanceB = _calculateDistance(
            midpointLat,
            midpointLng,
            placeB['latitude'],
            placeB['longitude'],
          );

          return distanceA.compareTo(distanceB);
        });

        if (placesWithAvailability.isNotEmpty) {
          // Return the closest place with suitable availability
          return {
            'place': placesWithAvailability[0]['place'],
            'meetup_time': placesWithAvailability[0]['meetup_time'],
          };
        }

        print('No places with suitable availability found');
        return null;
      } catch (e) {
        print('Error finding suitable place for meetup: $e');
        return null;
      }
    });
  }

  // Helper method to find a suitable time slot within a specific range
  static DateTime? _findSuitableTimeSlotWithinRange(
    Map<String, dynamic> placeAvailability,
    Map<String, dynamic>? user1Availability,
    Map<String, dynamic>? user2Availability,
    DateTime earliestTime,
    DateTime latestTime,
  ) {
    try {
      // Try to find a slot in the valid date range
      for (int dayOffset = 0; dayOffset < 4; dayOffset++) {
        // Check up to 4 days
        final targetDate = DateTime.now().add(Duration(days: dayOffset));

        // Skip if this date is outside our valid range
        if (targetDate.isBefore(
              earliestTime.subtract(const Duration(hours: 12)),
            ) ||
            targetDate.isAfter(latestTime.add(const Duration(hours: 12)))) {
          continue;
        }

        final String dayOfWeek =
            _getDayOfWeek(targetDate.weekday).toLowerCase();

        // Check if the place is open on this day
        if (!placeAvailability.containsKey(dayOfWeek)) {
          continue;
        }

        // Check if both users have availability defined for this day
        // If a day is missing in availability, consider the user unavailable that day
        if (user1Availability != null &&
            !user1Availability.containsKey(dayOfWeek)) {
          print(
            'User 1 has no availability defined for $dayOfWeek, skipping this day',
          );
          continue;
        }

        if (user2Availability != null &&
            !user2Availability.containsKey(dayOfWeek)) {
          print(
            'User 2 has no availability defined for $dayOfWeek, skipping this day',
          );
          continue;
        }

        // Get place opening hours for this day
        final Map<String, dynamic> placeHours = placeAvailability[dayOfWeek];
        if (!placeHours.containsKey('start') ||
            !placeHours.containsKey('end')) {
          continue;
        }

        // Parse place opening hours
        final TimeOfDay placeStart = _parseTimeString(placeHours['start']);
        final TimeOfDay placeEnd = _parseTimeString(placeHours['end']);

        // Adjust end time to be at least 1 hour before closing
        final TimeOfDay adjustedPlaceEnd = _subtractHours(placeEnd, 1);

        // If place closes too early, skip
        if (_compareTimeOfDay(placeStart, adjustedPlaceEnd) >= 0) {
          continue;
        }

        // Get user availabilities for this day
        Map<String, dynamic>? user1Hours;
        Map<String, dynamic>? user2Hours;

        if (user1Availability != null &&
            user1Availability.containsKey(dayOfWeek)) {
          user1Hours = user1Availability[dayOfWeek];
        }

        if (user2Availability != null &&
            user2Availability.containsKey(dayOfWeek)) {
          user2Hours = user2Availability[dayOfWeek];
        }

        // Parse user availability times
        TimeOfDay user1Start = TimeOfDay(
          hour: 9,
          minute: 0,
        ); // Default start time
        TimeOfDay user1End = TimeOfDay(hour: 22, minute: 0); // Default end time
        TimeOfDay user2Start = TimeOfDay(
          hour: 9,
          minute: 0,
        ); // Default start time
        TimeOfDay user2End = TimeOfDay(hour: 22, minute: 0); // Default end time

        if (user1Hours != null &&
            user1Hours.containsKey('start') &&
            user1Hours.containsKey('end')) {
          user1Start = _parseTimeString(user1Hours['start']);
          user1End = _parseTimeString(user1Hours['end']);
        }

        if (user2Hours != null &&
            user2Hours.containsKey('start') &&
            user2Hours.containsKey('end')) {
          user2Start = _parseTimeString(user2Hours['start']);
          user2End = _parseTimeString(user2Hours['end']);
        }

        // Find the latest start time and earliest end time
        TimeOfDay latestStart = _maxTimeOfDay(
          _maxTimeOfDay(placeStart, user1Start),
          user2Start,
        );

        TimeOfDay earliestEnd = _minTimeOfDay(
          _minTimeOfDay(adjustedPlaceEnd, user1End),
          user2End,
        );

        // If there's a valid time slot
        if (_compareTimeOfDay(latestStart, earliestEnd) < 0) {
          // Choose a time in the middle of the available slot
          final int startMinutes = latestStart.hour * 60 + latestStart.minute;
          final int endMinutes = earliestEnd.hour * 60 + earliestEnd.minute;
          final int middleMinutes = (startMinutes + endMinutes) ~/ 2;

          final int hour = middleMinutes ~/ 60;
          // Round minute to either 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, or 55
          final int minute = ((middleMinutes % 60) / 5).round() * 5;

          // Create the meetup time
          final proposedTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            hour,
            minute,
          );

          // Check if the proposed time is within our valid range
          if (proposedTime.isAfter(earliestTime) &&
              proposedTime.isBefore(latestTime)) {
            return proposedTime;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error finding suitable time slot within range: $e');
      return null;
    }
  }

  // Helper method to get day of week string
  static String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  // Helper method to parse time string (format: "HH:MM")
  static TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Helper method to compare two TimeOfDay objects
  static int _compareTimeOfDay(TimeOfDay time1, TimeOfDay time2) {
    final minutes1 = time1.hour * 60 + time1.minute;
    final minutes2 = time2.hour * 60 + time2.minute;
    return minutes1.compareTo(minutes2);
  }

  // Helper method to get the later of two TimeOfDay objects
  static TimeOfDay _maxTimeOfDay(TimeOfDay time1, TimeOfDay time2) {
    return _compareTimeOfDay(time1, time2) >= 0 ? time1 : time2;
  }

  // Helper method to get the earlier of two TimeOfDay objects
  static TimeOfDay _minTimeOfDay(TimeOfDay time1, TimeOfDay time2) {
    return _compareTimeOfDay(time1, time2) <= 0 ? time1 : time2;
  }

  // Helper method to subtract hours from a TimeOfDay
  static TimeOfDay _subtractHours(TimeOfDay time, int hours) {
    int totalMinutes = time.hour * 60 + time.minute - hours * 60;
    if (totalMinutes < 0) totalMinutes += 24 * 60;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  // Schedule a meetup for a match
  static Future<bool> scheduleMeetup(String matchId) async {
    return _safeApiCall(() async {
      if (currentUser == null) {
        print('SCHEDULE MEETUP: No current user, returning false');
        return false;
      }

      try {
        print('SCHEDULE MEETUP: Scheduling meetup for match: $matchId');

        // Get the match record
        print('SCHEDULE MEETUP: Fetching match record');
        final match =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('SCHEDULE MEETUP: Match record fetched: ${match.toString()}');

        // Determine the other user ID
        String otherUserId;
        if (match['user_id1'] == currentUser!.id) {
          otherUserId = match['user_id2'];
          print(
            'SCHEDULE MEETUP: Current user is user1, other user is user2: $otherUserId',
          );
        } else if (match['user_id2'] == currentUser!.id) {
          otherUserId = match['user_id1'];
          print(
            'SCHEDULE MEETUP: Current user is user2, other user is user1: $otherUserId',
          );
        } else {
          print('SCHEDULE MEETUP: Current user is not part of this match');
          return false;
        }

        // Find a suitable place and time
        print(
          'SCHEDULE MEETUP: Finding suitable place and time for meetup with user: $otherUserId',
        );
        final meetupDetails = await findSuitablePlaceForMeetup(otherUserId);

        if (meetupDetails == null) {
          print(
            'SCHEDULE MEETUP: Could not find suitable place and time for meetup, marking match as cancelled',
          );

          // Mark the match as cancelled due to no suitable place found
          // Set cancelled_by to null to indicate system cancellation
          await _supabaseClient
              .from('matches')
              .update({
                'is_cancelled': true,
                'cancelled_by': null, // System cancellation
              })
              .eq('id', matchId);

          print(
            'SCHEDULE MEETUP: Match marked as cancelled due to no suitable place',
          );
          return false;
        }

        print(
          'SCHEDULE MEETUP: Found suitable place: ${meetupDetails['place']['name']}',
        );
        print(
          'SCHEDULE MEETUP: Scheduled time: ${meetupDetails['meetup_time']}',
        );

        // Update the match record with place and time
        print('SCHEDULE MEETUP: Updating match record with place and time');
        final updateData = {
          'place_id': meetupDetails['place']['id'],
          'meetup_time': meetupDetails['meetup_time'],
          'is_cancelled': false,
          'cancelled_by': null,
          'is_meetup_passed': false,
        };
        print('SCHEDULE MEETUP: Update data: $updateData');

        await _supabaseClient
            .from('matches')
            .update(updateData)
            .eq('id', matchId);

        print('SCHEDULE MEETUP: Meetup scheduled successfully');

        // Verify the update was successful
        print('SCHEDULE MEETUP: Verifying update');
        final updatedMatch =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('SCHEDULE MEETUP: Updated match: ${updatedMatch.toString()}');
        print(
          'SCHEDULE MEETUP: Verification - place_id: ${updatedMatch['place_id']}',
        );
        print(
          'SCHEDULE MEETUP: Verification - meetup_time: ${updatedMatch['meetup_time']}',
        );

        // Check if both place_id and meetup_time were properly updated
        if (updatedMatch['place_id'] == null ||
            updatedMatch['meetup_time'] == null) {
          print(
            'SCHEDULE MEETUP: ERROR - Database update failed. place_id or meetup_time is null',
          );
          print('SCHEDULE MEETUP: Attempting to update the match record again');

          // Try one more time with a direct update
          try {
            await _supabaseClient
                .from('matches')
                .update({
                  'place_id': meetupDetails['place']['id'],
                  'meetup_time': meetupDetails['meetup_time'],
                })
                .eq('id', matchId);

            // Verify again
            final secondCheck =
                await _supabaseClient
                    .from('matches')
                    .select()
                    .eq('id', matchId)
                    .limit(1)
                    .single();

            if (secondCheck['place_id'] == null ||
                secondCheck['meetup_time'] == null) {
              print('SCHEDULE MEETUP: ERROR - Second update attempt failed');
              return false;
            }

            print('SCHEDULE MEETUP: Second update attempt successful');
            return true;
          } catch (e) {
            print(
              'SCHEDULE MEETUP: ERROR - Second update attempt threw exception: $e',
            );
            return false;
          }
        }

        return true;
      } catch (e) {
        print('SCHEDULE MEETUP: Error scheduling meetup: $e');
        return false;
      }
    });
  }

  // Get upcoming meetup for the current user
  static Future<Map<String, dynamic>?> getUpcomingMeetup() async {
    return _safeApiCall(() async {
      if (currentUser == null) {
        print(
          'MEETUP SERVICE: getUpcomingMeetup: No current user, returning null',
        );
        return null;
      }

      try {
        print(
          'MEETUP SERVICE: Checking for upcoming meetups for user: ${currentUser!.id}',
        );

        // Get current time
        final now = DateTime.now();
        print('MEETUP SERVICE: Current time: ${now.toIso8601String()}');

        // Query matches where current user is either user1 or user2
        // and there's a scheduled meetup in the future
        // and the meetup is not cancelled
        print(
          'MEETUP SERVICE: Querying database for upcoming meetups with SQL conditions:',
        );
        print('  - user_id1 or user_id2 = ${currentUser!.id}');
        print('  - meetup_time is not null');
        print('  - is_cancelled = false');
        print('  - is_meetup_passed = false');
        print('  - meetup_time > ${now.toIso8601String()}');

        final matches = await _supabaseClient
            .from('matches')
            .select('*, places(*)')
            .or('user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}')
            .not('meetup_time', 'is', null)
            .eq('is_cancelled', false)
            .eq('is_meetup_passed', false)
            .gt('meetup_time', now.toIso8601String())
            .order('meetup_time', ascending: true)
            .limit(1);

        print(
          'MEETUP SERVICE: Query completed, found ${matches.length} matches',
        );

        if (matches.isEmpty) {
          print('MEETUP SERVICE: No upcoming meetups found');
          return null;
        }

        final match = matches[0];
        print('MEETUP SERVICE: Found upcoming meetup: ${match['id']}');
        print(
          'MEETUP SERVICE: Meetup details: place_id=${match['place_id']}, time=${match['meetup_time']}',
        );
        print(
          'MEETUP SERVICE: Place details: ${match['places'] != null ? 'found' : 'not found'}',
        );

        // Print more details about the match
        print('MEETUP SERVICE: Full match record:');
        print('  id: ${match['id']}');
        print('  user_id1: ${match['user_id1']}');
        print('  user_id2: ${match['user_id2']}');
        print('  created_at: ${match['created_at']}');
        print('  place_id: ${match['place_id']}');
        print('  meetup_time: ${match['meetup_time']}');
        print('  is_cancelled: ${match['is_cancelled']}');
        print('  is_meetup_passed: ${match['is_meetup_passed']}');

        // Determine the other user ID
        String otherUserId;
        if (match['user_id1'] == currentUser!.id) {
          otherUserId = match['user_id2'];
          print(
            'MEETUP SERVICE: Current user is user1, other user is user2: $otherUserId',
          );
        } else {
          otherUserId = match['user_id1'];
          print(
            'MEETUP SERVICE: Current user is user2, other user is user1: $otherUserId',
          );
        }

        // Get the other user's profile
        print('MEETUP SERVICE: Fetching other user profile: $otherUserId');
        final otherUserProfile = await getProfileById(otherUserId);
        if (otherUserProfile == null) {
          print('MEETUP SERVICE: Could not retrieve other user profile');
          return null;
        }
        print('MEETUP SERVICE: Other user profile retrieved successfully');

        // Get current user's profile
        print('MEETUP SERVICE: Fetching current user profile');
        final currentUserProfile = await getUserProfile();
        if (currentUserProfile == null) {
          print('MEETUP SERVICE: Could not retrieve current user profile');
          return null;
        }
        print('MEETUP SERVICE: Current user profile retrieved successfully');

        // Return meetup details
        print('MEETUP SERVICE: Returning complete meetup details');
        return {
          'match': match,
          'place': match['places'],
          'other_user': otherUserProfile,
          'current_user': currentUserProfile,
        };
      } catch (e) {
        print('MEETUP SERVICE: Error getting upcoming meetup: $e');
        return null;
      }
    });
  }

  // Check if a meetup has passed
  static Future<bool> checkAndUpdateMeetupStatus() async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print(
          'Checking and updating meetup status for user: ${currentUser!.id}',
        );

        // Get current time
        final now = DateTime.now();

        // Query matches where current user is either user1 or user2
        // and there's a scheduled meetup in the past (more than 1 hour ago)
        // and the meetup is not marked as passed
        final matches = await _supabaseClient
            .from('matches')
            .select()
            .or('user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}')
            .not('meetup_time', 'is', null)
            .eq('is_cancelled', false)
            .eq('is_meetup_passed', false)
            .lt(
              'meetup_time',
              now.subtract(const Duration(hours: 1)).toIso8601String(),
            );

        if (matches.isEmpty) {
          print('No passed meetups found that need updating');
          return false;
        }

        print('Found ${matches.length} passed meetups to update');

        // Update all passed meetups
        for (final match in matches) {
          await _supabaseClient
              .from('matches')
              .update({'is_meetup_passed': true})
              .eq('id', match['id']);

          print('Updated meetup status to passed: ${match['id']}');
        }

        return true;
      } catch (e) {
        print('Error checking and updating meetup status: $e');
        return false;
      }
    });
  }

  // Cancel a meetup
  static Future<bool> cancelMeetup(String matchId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print('Cancelling meetup for match: $matchId');

        // Update the match record
        await _supabaseClient
            .from('matches')
            .update({'is_cancelled': true, 'cancelled_by': currentUser!.id})
            .eq('id', matchId);

        print('Meetup cancelled successfully');
        return true;
      } catch (e) {
        print('Error cancelling meetup: $e');
        return false;
      }
    });
  }

  // For debugging: Directly query matches with meetups
  static Future<List<Map<String, dynamic>>>
  debugQueryMatchesWithMeetups() async {
    return _safeApiCall(() async {
      if (currentUser == null) return [];

      try {
        print('DEBUG: Directly querying matches with meetups');

        // Query all matches for the current user that have a place_id (indicating a meetup)
        final matches = await _supabaseClient
            .from('matches')
            .select('*, places(*)')
            .or('user_id1.eq.${currentUser!.id},user_id2.eq.${currentUser!.id}')
            .not('place_id', 'is', null);

        print('DEBUG: Found ${matches.length} matches with place_id');

        // Print details of each match
        for (final match in matches) {
          print('DEBUG: Match ${match['id']}:');
          print('  place_id: ${match['place_id']}');
          print('  meetup_time: ${match['meetup_time']}');
          print('  is_cancelled: ${match['is_cancelled']}');
          print('  is_meetup_passed: ${match['is_meetup_passed']}');
          print(
            '  place: ${match['places'] != null ? match['places']['name'] : 'null'}',
          );
        }

        return matches;
      } catch (e) {
        print('DEBUG: Error querying matches with meetups: $e');
        return [];
      }
    });
  }

  // For debugging: Create a test meetup directly
  static Future<bool> createTestMeetupDirectly() async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print('DEBUG: Creating a test meetup directly');

        // First, create a test match
        final testMatch = await createTestMatch();
        if (testMatch == null) {
          print('DEBUG: Could not create test match');
          return false;
        }

        print('DEBUG: Created test match: ${testMatch['id']}');

        // Get all places
        final places = await _supabaseClient.from('places').select().limit(1);
        if (places.isEmpty) {
          print('DEBUG: No places found in the database');
          return false;
        }

        final place = places[0];
        print('DEBUG: Using place: ${place['name']}');

        // Create a meetup time (1 day from now)
        final meetupTime = DateTime.now().add(const Duration(days: 1));
        final meetupTimeString = meetupTime.toIso8601String();
        print('DEBUG: Using meetup time: $meetupTimeString');

        // Update the match with place and time
        await _supabaseClient
            .from('matches')
            .update({
              'place_id': place['id'],
              'meetup_time': meetupTimeString,
              'is_cancelled': false,
              'cancelled_by': null,
              'is_meetup_passed': false,
            })
            .eq('id', testMatch['id']);

        print('DEBUG: Test meetup created successfully');
        return true;
      } catch (e) {
        print('DEBUG: Error creating test meetup: $e');
        return false;
      }
    });
  }

  // For debugging: Test direct update of a match with meetup time
  static Future<bool> testDirectMatchUpdate(String matchId) async {
    return _safeApiCall(() async {
      if (currentUser == null) return false;

      try {
        print('DEBUG: Testing direct update of match: $matchId');

        // First, get the current match data
        final match =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('DEBUG: Current match data: $match');

        // Get a place to use
        final places = await _supabaseClient.from('places').select().limit(1);
        if (places.isEmpty) {
          print('DEBUG: No places found in the database');
          return false;
        }

        final place = places[0];
        print('DEBUG: Using place: ${place['name']} (${place['id']})');

        // Create a meetup time (1 day from now)
        final meetupTime = DateTime.now().add(const Duration(days: 1));
        final meetupTimeString = meetupTime.toIso8601String();
        print('DEBUG: Using meetup time: $meetupTimeString');

        // Try updating just the meetup_time first
        print('DEBUG: Attempting to update only meetup_time');
        await _supabaseClient
            .from('matches')
            .update({'meetup_time': meetupTimeString})
            .eq('id', matchId);

        // Verify the update
        final checkTime =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('DEBUG: After meetup_time update: ${checkTime['meetup_time']}');

        // Now try updating just the place_id
        print('DEBUG: Attempting to update only place_id');
        await _supabaseClient
            .from('matches')
            .update({'place_id': place['id']})
            .eq('id', matchId);

        // Verify the update
        final checkPlace =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('DEBUG: After place_id update: ${checkPlace['place_id']}');

        // Finally, try updating both together
        print('DEBUG: Attempting to update both fields together');
        await _supabaseClient
            .from('matches')
            .update({'meetup_time': meetupTimeString, 'place_id': place['id']})
            .eq('id', matchId);

        // Verify the final update
        final finalCheck =
            await _supabaseClient
                .from('matches')
                .select()
                .eq('id', matchId)
                .limit(1)
                .single();

        print('DEBUG: Final check - meetup_time: ${finalCheck['meetup_time']}');
        print('DEBUG: Final check - place_id: ${finalCheck['place_id']}');

        return finalCheck['meetup_time'] != null &&
            finalCheck['place_id'] != null;
      } catch (e) {
        print('DEBUG: Error in test direct match update: $e');
        return false;
      }
    });
  }
}
