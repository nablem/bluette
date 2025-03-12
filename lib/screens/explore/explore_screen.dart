import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../constants/app_theme.dart';
import '../../models/profile_filter.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_card.dart';
import 'filter_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermissionAndInitialize();

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
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    _cardController.dispose();
    _likeButtonController.dispose();
    _dislikeButtonController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, check if location permission was granted
    if (state == AppLifecycleState.resumed) {
      // Check if location permission status has changed
      _checkLocationStatusChange();
    }
  }

  // Check if location permission status has changed
  Future<void> _checkLocationStatusChange() async {
    // Only check if we don't already have permission
    if (!_isLocationPermissionGranted) {
      final isGranted = await LocationService.isLocationPermissionGranted();
      if (isGranted) {
        // Permission was granted in settings, reinitialize
        _checkLocationPermissionAndInitialize();
      }
    }
  }

  Future<void> _checkLocationPermissionAndInitialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request location permission using the native dialog
      final permissionStatus =
          await LocationService.requestLocationPermission();
      final isPermissionGranted =
          permissionStatus == LocationStatus.permissionGranted;

      setState(() {
        _isLocationPermissionGranted = isPermissionGranted;
        _locationStatus = permissionStatus;
        _isLoading = false;
      });

      if (isPermissionGranted) {
        // Only initialize explore if permission is granted
        await _initializeExplore();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking location permission: $e';
      });
    }
  }

  Future<void> _initializeExplore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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

      // Fetch profiles to swipe with current filter
      final profiles = await SupabaseService.getProfilesToSwipe(
        minAge: _currentFilter.minAge,
        maxAge: _currentFilter.maxAge,
        maxDistance: _currentFilter.maxDistance,
      );

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }

      // Log if no profiles were found
      if (profiles.isEmpty) {
        print(
          'No profiles found to swipe. User might have swiped all available profiles.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profiles: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyFilter(ProfileFilter filter) async {
    setState(() {
      _currentFilter = filter;
      _isLoading = true;
    });

    try {
      // Fetch profiles with the new filter
      final profiles = await SupabaseService.getProfilesToSwipe(
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        maxDistance: filter.maxDistance,
      );

      // Save filter preferences to user profile
      if (_userProfile != null) {
        await SupabaseService.updateUserData({
          'min_age': filter.minAge,
          'max_age': filter.maxAge,
          'max_distance': filter.maxDistance,
        });
      }

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error applying filter: $e';
          _isLoading = false;
        });
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
            }
          });
        }

        // Always fetch more profiles when we're down to the last 5
        // This ensures we always have profiles ready before the user runs out
        if (mounted && _profiles.length <= 5) {
          await _fetchMoreProfiles();
        }
      } catch (e) {
        print('Error recording swipe: $e');
      }
    }
  }

  Future<void> _fetchMoreProfiles() async {
    try {
      print('Fetching more profiles...');
      final newProfiles = await SupabaseService.getProfilesToSwipe(
        minAge: _currentFilter.minAge,
        maxAge: _currentFilter.maxAge,
        maxDistance: _currentFilter.maxDistance,
      );

      if (mounted) {
        if (newProfiles.isNotEmpty) {
          setState(() {
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
            } else {
              print('No new unique profiles found');
            }
          });
        } else {
          print('No more profiles available to fetch');
        }
      }
    } catch (e) {
      print('Error fetching more profiles: $e');
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

    print('Building ExploreScreen with $profileCount profiles');

    return Scaffold(
      // Removing the app bar for a cleaner, more immersive experience
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_isLocationPermissionGranted
                ? _buildLocationPermissionRequired()
                : _errorMessage != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _initializeExplore,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                : !hasProfiles
                ? _buildNoProfilesView()
                : Stack(
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
                ),
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
          ElevatedButton(
            onPressed: _checkLocationPermissionAndInitialize,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Grant Permission'),
          ),
          const SizedBox(height: 16),
          if (_locationStatus == LocationStatus.serviceDisabled)
            TextButton(
              onPressed: () async {
                await LocationService.openLocationSettings();
              },
              child: const Text('Open Location Settings'),
            )
          else if (_locationStatus == LocationStatus.permissionDeniedForever)
            TextButton(
              onPressed: () async {
                await LocationService.openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
        ],
      ),
    );
  }

  // Widget to show when there are no profiles to display
  Widget _buildNoProfilesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text('No more profiles to show', style: AppTheme.headingStyle),
          const SizedBox(height: 10),
          Text(
            'Try again later or adjust your preferences',
            style: AppTheme.bodyStyle,
            textAlign: TextAlign.center,
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
                onPressed: _initializeExplore,
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
}
