import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../constants/app_theme.dart';
import '../../models/profile_filter.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_card.dart';
import 'filter_dialog.dart';
import '../../utils/network_error_handler.dart';
import '../../widgets/error_message_widget.dart';
import '../../services/connectivity_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final CardSwiperController _cardController = CardSwiperController();
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  bool _isLocationPermissionGranted = false;
  String? _errorMessage;
  ProfileFilter _currentFilter = ProfileFilter.defaultFilter();
  Map<String, dynamic>? _userProfile;

  // Animation controllers for the like and dislike buttons
  late AnimationController _likeButtonController;
  late Animation<double> _likeButtonAnimation;
  late AnimationController _dislikeButtonController;
  late Animation<double> _dislikeButtonAnimation;

  // Add a class variable to store the location status
  LocationStatus _locationStatus = LocationStatus.permissionDenied;

  // Batch loading parameters
  static const int _batchSize = 5; // Number of profiles to fetch in each batch
  bool _isFetchingBatch =
      false; // Flag to prevent multiple simultaneous fetches
  bool _hasMoreProfiles = true; // Flag to track if more profiles are available
  int _currentBatchOffset = 0; // Offset for batch loading

  // Static flag to track if the screen has been initialized before
  static bool _hasBeenInitialized = false;

  // Static flag to track if location permission has been granted
  static bool _hasLocationPermission = false;

  // Static list to persist profiles between app launches
  static List<Map<String, dynamic>> _persistedProfiles = [];

  // Add a flag to track if we're returning to the screen
  bool _isReturningToScreen = false;

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // If location permission was previously granted, set it immediately
    if (_hasLocationPermission) {
      setState(() {
        _isLocationPermissionGranted = true;
      });
    }

    // Only do full initialization if this is the first time
    if (!_hasBeenInitialized) {
      _checkLocationPermissionAndInitialize();
    } else {
      // If we've been initialized before, set returning flag and restore persisted profiles
      setState(() {
        _isLoading = false;
        _isReturningToScreen = true;

        // Restore profiles from static list
        _profiles = List.from(_persistedProfiles);

        // Always ensure location permission is set correctly when returning
        if (_hasLocationPermission) {
          _isLocationPermissionGranted = true;
        }
      });

      // Clear returning flag after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isReturningToScreen = false;
          });
        }
      });

      // Reload user profile to get the latest filter values
      _reloadUserProfile();

      // If we have no profiles or very few, fetch more
      // This ensures we always have profiles to show, even after app restart
      if (_profiles.isEmpty) {
        // Reset batch offset to ensure we get all profiles
        _currentBatchOffset = 0;
        _hasMoreProfiles = true;
        _initializeExplore();
      } else if (_profiles.length < _batchSize) {
        _fetchMoreProfiles();
      }
    }

    // Initialize animation controllers - one for each button
    _likeButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _likeButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _likeButtonController, curve: Curves.easeOut),
    );

    // Create a separate controller for the dislike button
    _dislikeButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _dislikeButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _dislikeButtonController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // If we have static permission but the instance flag is not set, update it
    if (_hasLocationPermission && !_isLocationPermissionGranted) {
      setState(() {
        _isLocationPermissionGranted = true;
      });
    }

    // If we've been initialized before, reload the user profile to get the latest filter values
    if (_hasBeenInitialized && !_isLoading && !_isReturningToScreen) {
      _reloadUserProfile();
    }
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    _cardController.dispose();
    _likeButtonController.dispose();
    _dislikeButtonController.dispose();

    // Note: We intentionally don't reset _hasBeenInitialized here
    // to maintain state between navigations

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, check if location permission was granted
    if (state == AppLifecycleState.resumed) {
      // Check if location permission status has changed
      _checkLocationStatusChange();

      // Reload user profile to get the latest filter values
      if (_hasBeenInitialized) {
        _reloadUserProfile();
      }
    }
  }

  // Check if location permission status has changed
  Future<void> _checkLocationStatusChange() async {
    // Only check if we don't already have permission
    if (!_isLocationPermissionGranted) {
      final isGranted = await LocationService.isLocationPermissionGranted();
      if (isGranted) {
        // Update both instance and static flags
        setState(() {
          _isLocationPermissionGranted = true;
        });
        _hasLocationPermission = true;

        // Only reinitialize if we don't have profiles
        if (_profiles.isEmpty) {
          _checkLocationPermissionAndInitialize();
        }
      }
    }
  }

  Future<void> _checkLocationPermissionAndInitialize() async {
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

      // Request location permission using the native dialog
      final permissionStatus =
          await LocationService.requestLocationPermission();
      final isPermissionGranted =
          permissionStatus == LocationStatus.permissionGranted;

      // Update both instance and static flags
      setState(() {
        _isLocationPermissionGranted = isPermissionGranted;
        _locationStatus = permissionStatus;
        _isLoading = false;
      });

      // Update the static flag to remember permission was granted
      if (isPermissionGranted) {
        _hasLocationPermission = true;
      }

      if (isPermissionGranted) {
        // Only initialize explore if permission is granted
        await _initializeExplore();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
      });

      // Log the error for debugging
      print('Error in _checkLocationPermissionAndInitialize: ${e.toString()}');
    }
  }

  Future<void> _initializeExplore() async {
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

      // Update user location
      final locationUpdated = await LocationService.updateUserLocation();
      if (!locationUpdated) {
        print('Could not update location, but continuing to fetch profiles');
      }

      // Get user profile to initialize filter
      _userProfile = await SupabaseService.getUserProfile();
      if (_userProfile != null) {
        _currentFilter = ProfileFilter(
          minAge: _userProfile!['min_age'] ?? 18,
          maxAge: _userProfile!['max_age'] ?? 100,
          maxDistance: _userProfile!['max_distance'] ?? 5,
        );
      }

      // Reset batch loading parameters
      _currentBatchOffset = 0;
      _hasMoreProfiles = true;

      final profiles = await SupabaseService.getProfilesToSwipeBatch(
        minAge: _currentFilter.minAge,
        maxAge: _currentFilter.maxAge,
        maxDistance: _currentFilter.maxDistance,
        limit: _batchSize,
        offset: _currentBatchOffset,
      );

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
          _errorMessage = null;

          // Update batch parameters
          _currentBatchOffset += profiles.length;
          _hasMoreProfiles = profiles.length == (_batchSize);

          // Mark as initialized
          _hasBeenInitialized = true;

          // Update persisted profiles
          _persistedProfiles = List.from(profiles);
        });
      }

      // Log if no profiles were found
      if (profiles.isEmpty) {
        print(
          'No profiles found in first batch. Will attempt to fetch more if available.',
        );

        // If we didn't get any profiles but there might be more, try to fetch more
        if (_hasMoreProfiles) {
          // Use a short delay to avoid state conflicts
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _fetchMoreProfiles();
            }
          });
        } else {
          print('No more profiles available to fetch.');
          _hasMoreProfiles = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
          _isLoading = false;
        });

        // Log the error for debugging
        print('Error in _initializeExplore: ${e.toString()}');
      }
    }
  }

  Future<void> _applyFilter(ProfileFilter filter) async {
    setState(() {
      _currentFilter = filter;
      _isLoading = true;
      _errorMessage =
          null; // Always clear any error message when applying a filter
    });

    try {
      // Check for internet connection first
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        throw SocketException('No internet connection');
      }

      // Save filter preferences to user profile
      if (_userProfile != null) {
        print(
          'Saving filter preferences: min_age=${filter.minAge}, max_age=${filter.maxAge}, max_distance=${filter.maxDistance}',
        );

        await SupabaseService.updateUserData({
          'min_age': filter.minAge,
          'max_age': filter.maxAge,
          'max_distance': filter.maxDistance,
        });
      }

      // Reset batch loading parameters
      _currentBatchOffset = 0;
      _hasMoreProfiles = true;
      _isFetchingBatch = false;

      // Fetch first batch of profiles with the new filter
      final profiles = await SupabaseService.getProfilesToSwipeBatch(
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        maxDistance: filter.maxDistance,
        limit: _batchSize,
        offset: _currentBatchOffset,
      );

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
          // Always clear any error message when we successfully apply a filter
          _errorMessage = null;

          // Update batch parameters
          _currentBatchOffset += profiles.length;
          _hasMoreProfiles = profiles.length == _batchSize;

          // Update persisted profiles
          _persistedProfiles = List.from(profiles);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Only set error message if we have no profiles
          if (_profiles.isEmpty) {
            _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
          }
          _isLoading = false;
        });

        // Log the error for debugging
        print('Error in _applyFilter: ${e.toString()}');
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => FilterDialog(
            initialFilter: _currentFilter,
            onApplyFilter: _applyFilter,
            userAge: _userProfile?['age'],
          ),
    );
  }

  Future<void> _handleSwipe(int index, bool liked) async {
    if (index >= 0 && index < _profiles.length) {
      final swipedProfile = _profiles[index];
      final swipedProfileId = swipedProfile['id'];

      try {
        // Check for internet connection first
        final hasConnection = await ConnectivityService.isConnected();
        if (!hasConnection) {
          throw SocketException('No internet connection');
        }

        // Record the swipe in the database
        await SupabaseService.recordSwipe(
          swipedProfileId: swipedProfileId,
          liked: liked,
        );

        // If liked, check for a match
        if (liked) {
          final isMatch = await SupabaseService.checkForMatch(swipedProfileId);
          if (isMatch && mounted) {
            // Show match dialog
            _showMatchDialog(swipedProfile);
          }
        }

        // Wait a short delay to allow the swipe animation to complete
        // before removing the profile from the list
        await Future.delayed(const Duration(milliseconds: 300));

        // Remove the swiped profile from our list
        if (mounted) {
          setState(() {
            // Find the profile by ID to ensure we remove the correct one
            final index = _profiles.indexWhere(
              (p) => p['id'] == swipedProfileId,
            );
            if (index >= 0) {
              _profiles.removeAt(index);
              print(
                'Removed profile at index $index, ${_profiles.length} profiles remaining',
              );

              // Update persisted profiles
              _persistedProfiles = List.from(_profiles);
            }
          });
        }

        // Fetch more profiles when we're down to the last 3
        // This ensures we always have profiles ready before the user runs out
        if (mounted && _profiles.length <= 3 && _hasMoreProfiles) {
          await _fetchMoreProfiles();
        }
      } catch (e) {
        print('Error handling swipe: ${e.toString()}');

        // Set error message for network errors
        if (e is SocketException && mounted) {
          setState(() {
            _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
          });

          // Don't remove the profile from the list if we couldn't record the swipe
          // This way the user can try again when connection is restored
          return;
        }

        // For other errors, still remove the profile to avoid UI getting stuck
        if (mounted) {
          setState(() {
            // Find the profile by ID to ensure we remove the correct one
            final index = _profiles.indexWhere(
              (p) => p['id'] == swipedProfileId,
            );
            if (index >= 0) {
              _profiles.removeAt(index);
            }
          });

          // Try to fetch more profiles anyway
          if (_profiles.length <= 3 && _hasMoreProfiles) {
            await _fetchMoreProfiles();
          }
        }
      }
    }
  }

  Future<void> _fetchMoreProfiles() async {
    // If we're already fetching or there are no more profiles, don't fetch again
    if (_isFetchingBatch || !_hasMoreProfiles) {
      return;
    }

    // Set fetching flag to prevent multiple simultaneous fetches
    _isFetchingBatch = true;

    // If we have no profiles, we need to show a loading state
    if (_profiles.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Check for internet connection first
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        throw SocketException('No internet connection');
      }

      print(
        'Fetching more profiles (batch offset: $_currentBatchOffset, limit: $_batchSize)...',
      );
      final newProfiles = await SupabaseService.getProfilesToSwipeBatch(
        minAge: _currentFilter.minAge,
        maxAge: _currentFilter.maxAge,
        maxDistance: _currentFilter.maxDistance,
        limit: _batchSize,
        offset: _currentBatchOffset,
      );

      if (mounted) {
        // Always clear network error messages when we successfully make an API call
        if (_errorMessage != null &&
            (_errorMessage!.contains('internet') ||
                _errorMessage!.contains('connection'))) {
          setState(() {
            _errorMessage = null;
          });
        }

        if (newProfiles.isNotEmpty) {
          setState(() {
            // Always turn off loading state
            _isLoading = false;

            // Add new profiles, avoiding duplicates
            final existingIds = _profiles.map((p) => p['id']).toSet();
            final uniqueNewProfiles =
                newProfiles
                    .where((p) => !existingIds.contains(p['id']))
                    .toList();

            if (uniqueNewProfiles.isNotEmpty) {
              print(
                'Adding ${uniqueNewProfiles.length} new profiles to the stack',
              );
              _profiles.addAll(uniqueNewProfiles);

              // Update persisted profiles
              _persistedProfiles = List.from(_profiles);

              // Update batch parameters
              _currentBatchOffset += uniqueNewProfiles.length;
              // If we got fewer profiles than the batch size, there are no more profiles
              _hasMoreProfiles = newProfiles.length == _batchSize;
            } else {
              print('No new unique profiles found');
              // If we got profiles but none were unique, try the next batch
              _currentBatchOffset += newProfiles.length;

              // If we have no profiles at all, try to fetch more immediately
              if (_profiles.isEmpty && _hasMoreProfiles) {
                // Use a short delay to avoid infinite loops
                Future.delayed(const Duration(milliseconds: 500), () {
                  _fetchMoreProfiles();
                });
              }
            }
          });
        } else {
          print('No more profiles available to fetch');
          // No profiles returned means we've reached the end
          setState(() {
            _hasMoreProfiles = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching more profiles: ${e.toString()}');

      // Only set the error message when there's a network error AND there are no profiles
      // This ensures we don't show error messages when we have profiles to display
      if (mounted) {
        setState(() {
          if (_profiles.isEmpty) {
            _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
          }
          _isLoading = false;
        });
      }
    } finally {
      // Reset fetching flag
      _isFetchingBatch = false;
    }
  }

  void _showMatchDialog(Map<String, dynamic> matchedProfile) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('It\'s a Match!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('You and ${matchedProfile['name']} liked each other!'),
                const SizedBox(height: 20),
                // In a future implementation, we could add a button to start a conversation
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue Swiping'),
              ),
            ],
          ),
    );
  }

  // Function to animate the like button
  void _animateLikeButton() {
    if (_profiles.isNotEmpty) {
      _likeButtonController.reset();
      _likeButtonController.forward().then((_) {
        // Use the CardSwiper controller to swipe right after animation
        _cardController.swipe(CardSwiperDirection.right);
      });
    }
  }

  // Function to animate the dislike button
  void _animateDislikeButton() {
    if (_profiles.isNotEmpty) {
      _dislikeButtonController.reset();
      _dislikeButtonController.forward().then((_) {
        // Use the CardSwiper controller to swipe left after animation
        _cardController.swipe(CardSwiperDirection.left);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make sure we're showing the correct UI state
    final bool hasProfiles = _profiles.isNotEmpty;
    final int profileCount = _profiles.length;
    final bool isNetworkError =
        _errorMessage != null &&
        (_errorMessage!.contains('internet') ||
            _errorMessage!.contains('connection'));

    // Check if we have an active connection
    ConnectivityService.isConnected().then((hasConnection) {
      // If we have a connection but still show a network error, clear it
      if (hasConnection && isNetworkError && mounted) {
        setState(() {
          _errorMessage = null;
        });
      }

      // If we have no profiles but might have more available, try to fetch more
      if (!hasProfiles &&
          _hasMoreProfiles &&
          !_isLoading &&
          !_isFetchingBatch &&
          hasConnection &&
          mounted) {
        // Use a post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchMoreProfiles();
        });
      }
    });

    print('Building ExploreScreen with $profileCount profiles');

    return Scaffold(
      // Removing the app bar for a cleaner, more immersive experience
      body: SafeArea(
        child:
            _isLoading || _isReturningToScreen
                ? const Center(child: CircularProgressIndicator())
                // If we have profiles, always show them regardless of permission or error state
                : hasProfiles
                ? Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              top: 16.0,
                              bottom: 0.0,
                            ),
                            child: CardSwiper(
                              key: ValueKey(_profiles.length),
                              controller: _cardController,
                              cardsCount: _profiles.length,
                              onSwipe: (
                                previousIndex,
                                currentIndex,
                                direction,
                              ) async {
                                if (previousIndex < 0 ||
                                    previousIndex >= _profiles.length) {
                                  return false; // Invalid index, don't allow swipe
                                }

                                final liked =
                                    direction == CardSwiperDirection.right;

                                // Get a reference to the swiped profile
                                final swipedProfile = _profiles[previousIndex];
                                print(
                                  'Swiped profile: ${swipedProfile['name']} (${liked ? 'liked' : 'disliked'})',
                                );

                                // First allow the swipe animation to complete
                                // Then handle the swipe logic in the background
                                Future.microtask(() {
                                  _handleSwipe(previousIndex, liked);
                                });

                                // Return true to allow the default swipe animation
                                return true;
                              },
                              // Ensure we don't display more cards than available
                              numberOfCardsDisplayed:
                                  profileCount < 3 ? profileCount : 3,
                              backCardOffset: const Offset(20, 20),
                              padding: const EdgeInsets.all(24.0),
                              allowedSwipeDirection: AllowedSwipeDirection.only(
                                left: true,
                                right: true,
                              ),
                              isLoop: false, // Prevent looping
                              cardBuilder: (context, index, _, __) {
                                if (index < 0 || index >= _profiles.length) {
                                  print(
                                    'Invalid index: $index, profile count: ${_profiles.length}',
                                  );
                                  return const SizedBox.shrink();
                                }
                                print(
                                  'Building card for profile at index $index: ${_profiles[index]['name']}',
                                );
                                return ProfileCard(
                                  key: ValueKey(_profiles[index]['id']),
                                  profile: _profiles[index],
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 40.0,
                            right: 40.0,
                            top: 10.0,
                            bottom: 30.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Dislike button - wrapped in SizedBox to increase size
                              SizedBox(
                                width:
                                    70, // Increased size (default is around 56)
                                height:
                                    70, // Increased size (default is around 56)
                                child: AnimatedBuilder(
                                  animation: _dislikeButtonAnimation,
                                  builder: (context, child) {
                                    // Calculate the rotation based on the animation value
                                    final rotation =
                                        _dislikeButtonAnimation.value *
                                        3.14; // 180 degrees in radians

                                    return Transform(
                                      alignment: Alignment.center,
                                      transform:
                                          Matrix4.identity()
                                            ..setEntry(
                                              3,
                                              2,
                                              0.001,
                                            ) // perspective
                                            ..rotateY(rotation),
                                      child: FloatingActionButton(
                                        heroTag: 'dislike',
                                        onPressed: _animateDislikeButton,
                                        backgroundColor: Colors.white,
                                        elevation: 8.0,
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 45, // Increased icon size
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Like button - wrapped in SizedBox to increase size
                              SizedBox(
                                width:
                                    70, // Increased size (default is around 56)
                                height:
                                    70, // Increased size (default is around 56)
                                child: AnimatedBuilder(
                                  animation: _likeButtonAnimation,
                                  builder: (context, child) {
                                    // Calculate the rotation based on the animation value
                                    final rotation =
                                        _likeButtonAnimation.value *
                                        3.14; // 180 degrees in radians

                                    return Transform(
                                      alignment: Alignment.center,
                                      transform:
                                          Matrix4.identity()
                                            ..setEntry(
                                              3,
                                              2,
                                              0.001,
                                            ) // perspective
                                            ..rotateY(rotation),
                                      child: FloatingActionButton(
                                        heroTag: 'like',
                                        onPressed: _animateLikeButton,
                                        backgroundColor: AppTheme.primaryColor,
                                        elevation: 8.0,
                                        child: const Icon(
                                          Icons.favorite,
                                          color: Colors.white,
                                          size: 45, // Increased icon size
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Filter button in the top-right corner
                    Positioned(
                      top: 10,
                      right: 10,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'filter',
                        onPressed: _showFilterDialog,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.tune,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                )
                // When returning to the screen, we should never show the location permission screen
                // if we've been initialized before
                : _hasBeenInitialized && !_isLocationPermissionGranted
                ? Stack(
                  // This is a workaround to ensure we don't show the location permission screen
                  // when returning to the screen. We'll set the location permission flag to true
                  // and trigger a rebuild.
                  children: [
                    const Center(child: CircularProgressIndicator()),
                    Builder(
                      builder: (context) {
                        // Update the location permission flag if we have static permission
                        if (_hasLocationPermission) {
                          // Use a post-frame callback to avoid setState during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _isLocationPermissionGranted = true;
                              });
                            }
                          });
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                )
                // Location permission check only if we don't have profiles
                : !_isLocationPermissionGranted
                ? _buildLocationPermissionRequired()
                // Only show network error if we have no profiles
                : _errorMessage != null && isNetworkError
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorMessageWidget(
                        message: _errorMessage!,
                        onRetry: _checkLocationPermissionAndInitialize,
                        isNetworkError: true,
                      ),
                    ],
                  ),
                )
                // Show other errors if we have no profiles
                : _errorMessage != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorMessageWidget(
                        message: _errorMessage!,
                        onRetry: _initializeExplore,
                        isNetworkError: false,
                      ),
                    ],
                  ),
                )
                // No profiles and no errors
                : _buildNoProfilesView(),
      ),
    );
  }

  Widget _buildLocationPermissionRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'Location Access Required',
            style: AppTheme.headingStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'We need your location to show you nearby profiles. Please enable location services and grant permission.',
              style: AppTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          // Only show as TextButton if we're also showing another button
          if (_locationStatus == LocationStatus.serviceDisabled ||
              _locationStatus == LocationStatus.permissionDeniedForever)
            TextButton(
              onPressed: _checkLocationPermissionAndInitialize,
              child: const Text('Grant Permission'),
            )
          // Otherwise show as ElevatedButton with the same style as the other buttons
          else
            ElevatedButton(
              onPressed: _checkLocationPermissionAndInitialize,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Grant Permission'),
            ),
          const SizedBox(height: 16),
          if (_locationStatus == LocationStatus.serviceDisabled)
            ElevatedButton(
              onPressed: () async {
                await LocationService.openLocationSettings();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Open Location Settings'),
            )
          else if (_locationStatus == LocationStatus.permissionDeniedForever)
            ElevatedButton(
              onPressed: () async {
                await LocationService.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Open App Settings'),
            ),
        ],
      ),
    );
  }

  // Widget to show when there are no profiles to display
  Widget _buildNoProfilesView() {
    // Check if there's a network error
    final bool isNetworkError =
        _errorMessage != null &&
        (_errorMessage!.contains('internet') ||
            _errorMessage!.contains('connection'));

    // If there's a network error, show the network error message instead
    if (isNetworkError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ErrorMessageWidget(
              message: _errorMessage!,
              onRetry: _checkLocationPermissionAndInitialize,
              isNetworkError: true,
            ),
            const SizedBox(height: 20),
            Text(
              'Your swipes may not have been saved due to connection issues.',
              style: AppTheme.smallTextStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // If we're fetching more profiles or we have more profiles available, show loading
    if (_isFetchingBatch || (_hasMoreProfiles && _profiles.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading more profiles...'),
          ],
        ),
      );
    }

    // Otherwise show the regular no profiles view
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text('No more profiles to show', style: AppTheme.headingStyle),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'You\'ve seen all profiles that match your current preferences. Try adjusting your filters or check back later for new users.',
              style: AppTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showFilterDialog,
                icon: const Icon(Icons.tune),
                label: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text('Adjust Filters'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // Clear any error message before refreshing
                  setState(() {
                    _errorMessage = null;
                    // Reset batch offset to ensure we get all profiles
                    _currentBatchOffset = 0;
                    _hasMoreProfiles = true;
                  });
                  _initializeExplore();
                },
                icon: const Icon(Icons.refresh),
                label: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text('Refresh'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // For testing purposes - clear swipes
          TextButton.icon(
            onPressed: () async {
              try {
                await SupabaseService.clearUserSwipes();
                // Clear any error message before refreshing
                setState(() {
                  _errorMessage = null;
                });
                _initializeExplore();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error clearing swipes: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All Swipes (Testing)'),
          ),
        ],
      ),
    );
  }

  // Add a method to reload the user profile and update filter values
  Future<void> _reloadUserProfile() async {
    try {
      // Get the latest user profile from the database
      final userProfile = await SupabaseService.getUserProfile();
      if (userProfile != null && mounted) {
        setState(() {
          _userProfile = userProfile;
          // Update the filter with the latest values from the database
          _currentFilter = ProfileFilter(
            minAge: userProfile['min_age'] ?? 18,
            maxAge: userProfile['max_age'] ?? 100,
            maxDistance: userProfile['max_distance'] ?? 5,
          );
        });
        print(
          'Reloaded user profile with filter values: min_age=${_currentFilter.minAge}, max_age=${_currentFilter.maxAge}, max_distance=${_currentFilter.maxDistance}',
        );
      }
    } catch (e) {
      print('Error reloading user profile: ${e.toString()}');
    }
  }
}
