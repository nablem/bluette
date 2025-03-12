import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import '../../constants/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';
import 'edit_field_dialog.dart';
import 'edit_profile_picture.dart';
import 'edit_voice_bio.dart';

// Add missing import for AudioSource
import 'package:just_audio/just_audio.dart' show AudioSource;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _showMoreOptions = false;
  bool _isPlayingAudio = false;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;
  final _audioPlayer = AudioPlayer();
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We don't want to reload the profile here as it would reset any local changes
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // We don't want to reload the profile here either
  }

  void _setupAudioPlayerListeners() {
    // Cancel any existing subscriptions
    _playerSubscription?.cancel();

    // Listen to player state changes
    _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        print(
          'Audio player state changed: ${state.processingState}, playing: ${state.playing}',
        );

        if (state.processingState == ProcessingState.completed) {
          // When playback completes, update UI
          setState(() {
            _isPlayingAudio = false;
          });
        } else if (state.processingState == ProcessingState.idle &&
            state.playing == false &&
            _isPlayingAudio) {
          // Handle error or unexpected state
          print('Audio player in idle state but UI shows playing');
          setState(() {
            _isPlayingAudio = false;
            _errorMessage = 'Audio playback stopped unexpectedly';
          });
        }
      }
    });

    // Also listen for errors
    _audioPlayer.playbackEventStream.listen(
      (event) {
        // Handle playback events if needed
      },
      onError: (Object e, StackTrace st) {
        print('Audio player error: $e');
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _errorMessage = 'Error playing audio: ${e.toString()}';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    if (_isPlayingAudio) {
      _audioPlayer.stop();
    }
    _playerSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await SupabaseService.getUserProfile();

      // Debug print to check profile data
      print('Loaded profile: $profile');

      // Check if we need to refresh the URLs
      if (profile != null) {
        // Refresh profile picture URL if it exists but might be expired
        if (profile['profile_picture_url'] != null) {
          print('Refreshing profile picture URL');
          final newImageUrl = await SupabaseService.refreshProfilePictureUrl();
          if (newImageUrl != null &&
              newImageUrl != profile['profile_picture_url']) {
            profile['profile_picture_url'] = newImageUrl;
          }
        }

        // Refresh voice bio URL if it exists but might be expired
        if (profile['voice_bio_url'] != null) {
          print('Refreshing voice bio URL');
          final newAudioUrl = await SupabaseService.refreshVoiceBioUrl();
          if (newAudioUrl != null && newAudioUrl != profile['voice_bio_url']) {
            profile['voice_bio_url'] = newAudioUrl;
          }
        }

        if (profile['profile_picture_url'] != null) {
          print('Profile picture URL: ${profile['profile_picture_url']}');
        }

        if (profile['voice_bio_url'] != null) {
          print('Voice bio URL: ${profile['voice_bio_url']}');
        }
      }

      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateField(String field, dynamic value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = {'id': SupabaseService.currentUser!.id, field: value};

      // Update local state immediately to show the change
      if (_userProfile != null) {
        // Create a deep copy of the user profile to avoid reference issues
        final updatedProfile = Map<String, dynamic>.from(_userProfile!);
        updatedProfile[field] = value;

        setState(() {
          _userProfile = updatedProfile;
        });
      }

      // Update the database
      await SupabaseService.updateUserData(userData);

      // No need to reload the profile since we've already updated the local state
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update $field: ${e.toString()}';
        _isLoading = false;
      });

      // Don't reload the profile here, as it might overwrite local changes
      // Just log the error and let the user try again if needed
      print('Error updating field $field: $e');
    }
  }

  Future<void> _editField(
    String field,
    String currentValue,
    String label,
  ) async {
    // For age field, we need to handle the integer return type
    if (field == 'age') {
      final result = await showDialog<int>(
        context: context,
        builder:
            (context) => EditFieldDialog(
              initialValue: currentValue,
              label: label,
              field: field,
            ),
      );

      if (result != null && result.toString() != currentValue) {
        await _updateField(field, result);
      }
    } else {
      // For other fields, handle string return type
      final result = await showDialog<String>(
        context: context,
        builder:
            (context) => EditFieldDialog(
              initialValue: currentValue,
              label: label,
              field: field,
            ),
      );

      if (result != null && result != currentValue) {
        await _updateField(field, result);
      }
    }
  }

  Future<void> _editProfilePicture() async {
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePicture()),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Save the current profile state before updating
        final currentProfile =
            _userProfile != null
                ? Map<String, dynamic>.from(_userProfile!)
                : null;

        final imageUrl = await SupabaseService.uploadProfilePicture(result);

        // Update local state with the new image URL but preserve other fields
        if (currentProfile != null && imageUrl != null) {
          currentProfile['profile_picture_url'] = imageUrl;
          setState(() {
            _userProfile = currentProfile;
            _isLoading = false;
          });
        } else {
          // Only reload if we couldn't update locally
          setState(() {
            _isLoading = false;
          });
          if (_userProfile == null) {
            await _loadUserProfile();
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to update profile picture: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editVoiceBio() async {
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (context) => const EditVoiceBio()),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Save the current profile state before updating
        final currentProfile =
            _userProfile != null
                ? Map<String, dynamic>.from(_userProfile!)
                : null;

        final audioUrl = await SupabaseService.uploadVoiceBio(result);

        // Update local state with the new audio URL but preserve other fields
        if (currentProfile != null && audioUrl != null) {
          currentProfile['voice_bio_url'] = audioUrl;
          setState(() {
            _userProfile = currentProfile;
            _isLoading = false;
          });
        } else {
          // Only reload if we couldn't update locally
          setState(() {
            _isLoading = false;
          });
          if (_userProfile == null) {
            await _loadUserProfile();
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to update voice bio: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playVoiceBio() async {
    if (_userProfile == null || _userProfile!['voice_bio_url'] == null) {
      print('No voice bio URL available');
      setState(() {
        _errorMessage = 'No voice bio available';
      });
      return;
    }

    // Refresh the voice bio URL before playing
    String audioUrl = _userProfile!['voice_bio_url'];
    try {
      final refreshedUrl = await SupabaseService.refreshVoiceBioUrl();
      if (refreshedUrl != null) {
        audioUrl = refreshedUrl;
        // Update local state
        final updatedProfile = Map<String, dynamic>.from(_userProfile!);
        updatedProfile['voice_bio_url'] = refreshedUrl;
        setState(() {
          _userProfile = updatedProfile;
        });
      }
    } catch (e) {
      print('Error refreshing voice bio URL: $e');
      // Continue with the existing URL
    }

    print('Attempting to play voice bio: $audioUrl');

    try {
      if (_isPlayingAudio) {
        // Stop playback if already playing
        print('Stopping current playback');
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
        });
        return;
      }

      // Reset player and clear any previous errors
      await _audioPlayer.stop();
      setState(() {
        _errorMessage = null;
        _isPlayingAudio = true;
      });

      // Try a more direct approach for Android
      try {
        print('Setting audio URL: $audioUrl');
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));

        print('Starting audio playback');
        await _audioPlayer.play();
        print('Playback started successfully');
      } catch (audioError) {
        print('Error with AudioSource approach: $audioError');

        // Fallback to simpler approach
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error playing voice bio: $e');
      setState(() {
        _isPlayingAudio = false;
        _errorMessage = 'Failed to play voice bio: ${e.toString()}';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to log out: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Delete user data from profiles table
        await SupabaseService.deleteUserData();

        // Sign out and navigate to login
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to delete account: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfilePicture() {
    String? profilePictureUrl = _userProfile?['profile_picture_url'];
    bool hasValidUrl =
        profilePictureUrl != null && profilePictureUrl.isNotEmpty;

    print('Building profile picture with URL: $profilePictureUrl');

    return GestureDetector(
      onTap: _editProfilePicture,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 3),
            ),
            child:
                hasValidUrl
                    ? ClipOval(
                      child: Image.network(
                        profilePictureUrl,
                        fit: BoxFit.cover,
                        // Don't use cacheWidth/cacheHeight with signed URLs
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading profile image: $error');
                          // Try to refresh the URL if there's an error
                          _refreshProfilePictureUrlOnError();
                          return const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                    )
                    : const Icon(Icons.person, size: 80, color: Colors.grey),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // Helper method to refresh the profile picture URL if there's an error
  Future<void> _refreshProfilePictureUrlOnError() async {
    if (!mounted) return;

    try {
      final newUrl = await SupabaseService.refreshProfilePictureUrl();
      if (newUrl != null && mounted) {
        // Update the local state with the new URL
        setState(() {
          final updatedProfile = Map<String, dynamic>.from(_userProfile!);
          updatedProfile['profile_picture_url'] = newUrl;
          _userProfile = updatedProfile;
        });
      }
    } catch (e) {
      print('Error refreshing profile picture URL on error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removing the app bar for a cleaner, more immersive experience
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userProfile == null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'Failed to load profile',
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.errorColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Try Again',
                        onPressed: _loadUserProfile,
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _loadUserProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile Picture
                          _buildProfilePicture().animate().fadeIn(
                            duration: 600.ms,
                          ),
                          const SizedBox(height: 24),

                          // Name
                          _buildEditableField(
                            'Name',
                            _userProfile!['name'] ?? 'Not set',
                            Icons.person,
                            () => _editField(
                              'name',
                              _userProfile!['name'] ?? '',
                              'Name',
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 600.ms),

                          // Age
                          _buildEditableField(
                            'Age',
                            _userProfile!['age']?.toString() ?? 'Not set',
                            Icons.cake,
                            () => _editField(
                              'age',
                              _userProfile!['age']?.toString() ?? '',
                              'Age',
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                          // Gender
                          _buildEditableField(
                            'Gender',
                            _userProfile!['gender'] ?? 'Not set',
                            Icons.wc,
                            () => _editField(
                              'gender',
                              _userProfile!['gender'] ?? '',
                              'Gender',
                            ),
                          ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

                          // Interested In
                          _buildEditableField(
                            'Interested In',
                            _userProfile!['interested_in'] ?? 'Not set',
                            Icons.favorite,
                            () => _editField(
                              'interested_in',
                              _userProfile!['interested_in'] ?? '',
                              'Interested In',
                            ),
                          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                          const SizedBox(height: 32),

                          // Voice Bio
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice Bio',
                                  style: AppTheme.subtitleStyle,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap:
                                            _userProfile!['voice_bio_url'] !=
                                                    null
                                                ? _playVoiceBio
                                                : null,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _isPlayingAudio
                                                    ? Icons.stop
                                                    : Icons.play_arrow,
                                                color: AppTheme.primaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isPlayingAudio
                                                    ? 'Playing...'
                                                    : (_userProfile!['voice_bio_url'] !=
                                                            null
                                                        ? 'Play Voice Bio'
                                                        : 'No Voice Bio'),
                                                style: AppTheme.bodyStyle
                                                    .copyWith(
                                                      color:
                                                          AppTheme.primaryColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _editVoiceBio,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                          const SizedBox(height: 40),

                          // More Options
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showMoreOptions = !_showMoreOptions;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'More Options',
                                  style: AppTheme.bodyStyle.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showMoreOptions
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                          // More Options Expanded
                          if (_showMoreOptions)
                            Column(
                              children: [
                                const SizedBox(height: 24),
                                CustomButton(
                                  text: 'Log Out',
                                  onPressed: _logout,
                                  icon: Icons.logout,
                                  isOutlined: true,
                                ),
                                const SizedBox(height: 16),
                                CustomButton(
                                  text: 'Delete Account',
                                  onPressed: _deleteAccount,
                                  icon: Icons.delete_forever,
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              ],
                            ).animate().fadeIn(duration: 300.ms),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    String value,
    IconData icon,
    VoidCallback onEdit,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.smallTextStyle.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
