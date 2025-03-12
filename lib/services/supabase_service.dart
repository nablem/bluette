import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseService {
  static final SupabaseClient _supabaseClient = Supabase.instance.client;

  // Get current user
  static User? get currentUser => _supabaseClient.auth.currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final response = await _supabaseClient.auth.signUp(
      email: email,
      password: password,
      data: userData,
    );

    return response;
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return response;
  }

  // Sign out
  static Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    await _supabaseClient.auth.resetPasswordForEmail(email);
  }

  // Update user data
  static Future<void> updateUserData(Map<String, dynamic> userData) async {
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
    } else {
      // Default values if somehow no user
      if (!userData.containsKey('email') ||
          userData['email'] == null ||
          userData['email'].toString().isEmpty) {
        userData['email'] =
            'anonymous_${DateTime.now().millisecondsSinceEpoch}@example.com';
      }
      if (!userData.containsKey('name') ||
          userData['name'] == null ||
          userData['name'].toString().isEmpty) {
        userData['name'] = 'Anonymous_${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    // Log the data we're updating
    print('Updating user data: $userData');

    try {
      // Make sure we're using upsert with the correct primary key
      if (!userData.containsKey('id') && currentUser != null) {
        userData['id'] = currentUser!.id;
      }

      // If we're updating the name, also update it in the user's metadata
      if (userData.containsKey('name') && currentUser != null) {
        try {
          // Update the user's metadata in the auth system
          await _supabaseClient.auth.updateUser(
            UserAttributes(data: {'name': userData['name']}),
          );
          print('Updated name in user metadata: ${userData['name']}');
        } catch (e) {
          print('Error updating user metadata: $e');
          // Continue with the profile update even if metadata update fails
        }
      }

      // Ensure we're doing a proper upsert with onConflict parameter
      print('Performing upsert with data: $userData');

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
        } catch (e) {
          print('Error fetching existing profile: $e');
          // Continue with the update even if we can't fetch the existing profile
        }
      }

      // Perform the upsert operation
      final response = await _supabaseClient
          .from('profiles')
          .upsert(userData, onConflict: 'id');

      print('Upsert response: $response');
      print('Profile updated successfully');

      // Verify the update by fetching the profile again
      if (userData.containsKey('name') && currentUser != null) {
        final updatedProfile =
            await _supabaseClient
                .from('profiles')
                .select()
                .eq('id', currentUser!.id)
                .single();

        print('Verified profile after update: $updatedProfile');
        print('Verified name after update: ${updatedProfile['name']}');

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
    } catch (e) {
      print('Error updating profile: $e');
      throw e;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;

    final response =
        await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', currentUser!.id)
            .single();

    return response;
  }

  // Upload profile picture
  static Future<String?> uploadProfilePicture(File imageFile) async {
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
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
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

  // Fetch profiles based on gender preference
  static Future<List<Map<String, dynamic>>> getProfilesToSwipe() async {
    if (currentUser == null) return [];

    try {
      // Get current user profile to determine gender preference
      final userProfile = await getUserProfile();
      if (userProfile == null) return [];

      final String? interestedIn = userProfile['interested_in'];
      if (interestedIn == null) return [];

      // Get user's already swiped profiles
      final swipedProfiles = await _supabaseClient
          .from('swipes')
          .select('swiped_profile_id')
          .eq('user_id', currentUser!.id);

      final List<String> swipedProfileIds =
          swipedProfiles.isNotEmpty
              ? List<String>.from(
                swipedProfiles.map((profile) => profile['swiped_profile_id']),
              )
              : [];

      print('Already swiped profiles: $swipedProfileIds');

      // Build query based on gender preference
      var query = _supabaseClient
          .from('profiles')
          .select()
          .neq('id', currentUser!.id); // Exclude current user

      // Filter out already swiped profiles
      if (swipedProfileIds.isNotEmpty) {
        // Use 'not in' to exclude all swiped profile IDs
        query = query.not('id', 'in', swipedProfileIds);
      }

      // Apply gender filter based on preference
      if (interestedIn != 'Everyone') {
        query = query.eq('gender', interestedIn);
      }

      final profiles = await query.limit(20);
      print('Fetched ${profiles.length} profiles to swipe');

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      print('Error fetching profiles to swipe: $e');
      return [];
    }
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
