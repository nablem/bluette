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
import '../../utils/network_error_handler.dart';
import '../../widgets/error_message_widget.dart';
import '../../services/connectivity_service.dart';

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

  // Static variables to cache profile data and track initialization
  static bool _hasBeenInitialized = false;
  static Map<String, dynamic>? _cachedProfile;
  static DateTime? _lastLoadTime;
  // Add a static image cache
  static ImageProvider? _cachedImageProvider;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();

    // Always load the profile when the app starts
    _loadUserProfile();

    // Check if we have a cached profile and if it's recent enough (less than 5 minutes old)
    final bool hasFreshCache =
        _hasBeenInitialized &&
        _cachedProfile != null &&
        _lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!).inMinutes < 5;

    if (hasFreshCache) {
      // Use cached data while loading
      setState(() {
        _userProfile = Map<String, dynamic>.from(_cachedProfile!);
        _isLoading = false;
      });

      // Preload the profile image to prevent flickering
      String? profilePictureUrl = _cachedProfile?['profile_picture_url'];
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        // Create and cache the image provider if not already cached
        _cachedImageProvider ??= NetworkImage(profilePictureUrl);

        // Use a post-frame callback to ensure the context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _cachedImageProvider != null) {
            precacheImage(_cachedImageProvider!, context);
          }
        });
      }
    }
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
        if (state.processingState == ProcessingState.completed) {
          // When playback completes, update UI
          setState(() {
            _isPlayingAudio = false;
          });
        } else if (state.processingState == ProcessingState.idle &&
            state.playing == false &&
            _isPlayingAudio) {
          // Handle error or unexpected state

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
      // Check for internet connection first
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        throw SocketException('No internet connection');
      }

      final profile = await SupabaseService.getUserProfile();

      // Debug print to check profile data

      // Check if we need to refresh the URLs
      if (profile != null) {
        // Refresh profile picture URL if it exists but might be expired
        if (profile['profile_picture_url'] != null) {
          final newImageUrl = await SupabaseService.refreshProfilePictureUrl();
          if (newImageUrl != null &&
              newImageUrl != profile['profile_picture_url']) {
            profile['profile_picture_url'] = newImageUrl;

            // Update the cached image provider with the new URL
            _cachedImageProvider = NetworkImage(newImageUrl);

            // Precache the new image
            if (mounted) {
              precacheImage(_cachedImageProvider!, context);
            }
          }
        }

        // Refresh voice bio URL if it exists but might be expired
        if (profile['voice_bio_url'] != null) {
          final newAudioUrl = await SupabaseService.refreshVoiceBioUrl();
          if (newAudioUrl != null && newAudioUrl != profile['voice_bio_url']) {
            profile['voice_bio_url'] = newAudioUrl;
          }
        }

        if (profile['profile_picture_url'] != null) {}

        if (profile['voice_bio_url'] != null) {}
      }

      // Update the cache
      _cachedProfile =
          profile != null ? Map<String, dynamic>.from(profile) : null;
      _lastLoadTime = DateTime.now();
      _hasBeenInitialized = true;

      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
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

        // Invalidate the cache
        _cachedProfile = null;
        _lastLoadTime = null;
        _hasBeenInitialized = false;
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

          // Update the cached image provider with the new URL
          _cachedImageProvider = NetworkImage(imageUrl);

          // Precache the new image
          if (mounted) {
            precacheImage(_cachedImageProvider!, context);
          }

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
      // Continue with the existing URL
    }

    try {
      if (_isPlayingAudio) {
        // Stop playback if already playing

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
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));

        await _audioPlayer.play();
      } catch (audioError) {
        // Fallback to simpler approach
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
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

    return GestureDetector(
      onTap: _editProfilePicture,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 3),
            ),
            child:
                hasValidUrl
                    ? ClipOval(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: Image.network(
                          profilePictureUrl,
                          fit: BoxFit.cover,
                          key: ValueKey('profile-$profilePictureUrl'),
                          errorBuilder: (context, error, stackTrace) {
                            _refreshProfilePictureUrlOnError();
                            return const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.grey,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              // Cache the image provider for future use
                              _cachedImageProvider = NetworkImage(
                                profilePictureUrl,
                              );
                              return child;
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
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
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single build method that works for both first load and returning to screen
    return Scaffold(
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userProfile == null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorMessageWidget(
                        message: _errorMessage ?? 'Failed to load profile',
                        onRetry: _loadUserProfile,
                        isNetworkError:
                            _errorMessage != null &&
                            (_errorMessage!.contains('internet') ||
                                _errorMessage!.contains('connection')),
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
                          // Profile Picture - always with animation for better visibility
                          _buildProfilePicture().animate().fadeIn(
                            duration: 800.ms,
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
                          _buildVoiceBioSection().animate().fadeIn(
                            delay: 500.ms,
                            duration: 600.ms,
                          ),

                          const SizedBox(height: 40),

                          // More Options
                          _buildMoreOptionsButton().animate().fadeIn(
                            delay: 600.ms,
                            duration: 600.ms,
                          ),

                          // More Options Expanded
                          if (_showMoreOptions)
                            _buildMoreOptionsContent().animate().fadeIn(
                              duration: 300.ms,
                            ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  // Helper method to build the voice bio section
  Widget _buildVoiceBioSection() {
    return Container(
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
          Text('Voice Bio', style: AppTheme.subtitleStyle),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap:
                      _userProfile!['voice_bio_url'] != null
                          ? _playVoiceBio
                          : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPlayingAudio ? Icons.stop : Icons.play_arrow,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPlayingAudio
                              ? 'Playing...'
                              : (_userProfile!['voice_bio_url'] != null
                                  ? 'Play Voice Bio'
                                  : 'No Voice Bio'),
                          style: AppTheme.bodyStyle.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build the more options button
  Widget _buildMoreOptionsButton() {
    return GestureDetector(
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
            style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade700),
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
    );
  }

  // Helper method to build the more options content
  Widget _buildMoreOptionsContent() {
    return Column(
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
            color: Colors.black.withAlpha(13),
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
              color: AppTheme.primaryColor.withAlpha(26),
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
