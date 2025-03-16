import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_theme.dart';
import '../../models/profile_filter.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_card.dart';
import 'filter_dialog.dart';
import '../../utils/network_error_handler.dart';
import '../../widgets/error_message_widget.dart';
import '../../services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'meetup_view.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  // Static method to clear the shown matches set
  static void clearShownMatches() {
    _ExploreScreenState.clearShownMatches();
  }

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

  // Add a variable to store upcoming meetup details
  Map<String, dynamic>? _upcomingMeetup;
  bool _isCheckingMeetup = false;

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

  // Static set to track which matches have already been shown to the user
  static Set<String> _shownMatchIds = {};

  // Key for storing shown match IDs in SharedPreferences
  static const String _shownMatchIdsKey = 'shown_match_ids';

  // Add a flag to track if we're returning to the screen
  bool _isReturningToScreen = false;

  // Add a confetti controller for match animation
  late ConfettiController _confettiController;

  // Add a variable to store the realtime subscription
  RealtimeChannel? _matchSubscription;

  // Add a variable to track if we need to check for unseen matches
  bool _needToCheckUnseenMatches = true;

  // Timer for periodic subscription check
  Timer? _subscriptionCheckTimer;

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Initialize confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Load shown match IDs from storage
    _loadShownMatchIds().then((_) {
      print('Shown match IDs loaded, count: ${_shownMatchIds.length}');
    });

    // Check for upcoming meetups
    _checkForUpcomingMeetup();

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

    // Subscribe to real-time match events
    _subscribeToMatches();

    // Always check for unseen matches when the app starts
    // Use a short delay to ensure the UI is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Always set this to true to ensure we check for matches
        _needToCheckUnseenMatches = true;
        _checkForUnseenMatches();
      }
    });

    // Start periodic check for subscription health
    _startPeriodicSubscriptionCheck();
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
    _confettiController.dispose();

    // Cancel subscription check timer
    _subscriptionCheckTimer?.cancel();
    _subscriptionCheckTimer = null;

    // Unsubscribe from real-time match events
    if (_matchSubscription != null) {
      print('Disposing match subscription');
      Supabase.instance.client.removeChannel(_matchSubscription!);
      _matchSubscription = null;
    }

    // Note: We intentionally don't reset _hasBeenInitialized here
    // to maintain state between navigations

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, check if location permission was granted
    if (state == AppLifecycleState.resumed) {
      print('App resumed from background, checking subscriptions and matches');

      // Check if location permission status has changed
      _checkLocationStatusChange();

      // Reload user profile to get the latest filter values
      if (_hasBeenInitialized) {
        _reloadUserProfile();
      }

      // Check for upcoming meetups
      _checkForUpcomingMeetup();

      // Ensure we have an active match subscription
      if (_matchSubscription == null) {
        print('Match subscription is null on resume, resubscribing');
        _subscribeToMatches();
      } else {
        // For safety, resubscribe to ensure we have a fresh connection
        print('Refreshing match subscription on app resume');
        _subscribeToMatches();
      }

      // Always check for unseen matches when app resumes
      // Use a short delay to ensure the UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkForUnseenMatches();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      print('App paused, current subscription will be maintained');
    }
  }

  // Subscribe to real-time match events
  void _subscribeToMatches() {
    try {
      // Clean up any existing subscription first
      if (_matchSubscription != null) {
        print('Removing existing match subscription before creating a new one');
        Supabase.instance.client.removeChannel(_matchSubscription!);
        _matchSubscription = null;
      }

      print('Setting up real-time subscription for matches');

      // Enable real-time for the client
      try {
        print('Ensuring realtime is connected');
        // ignore: invalid_use_of_internal_member
        Supabase.instance.client.realtime.connect();
      } catch (e) {
        print('Error connecting realtime: $e');
      }

      final channel = Supabase.instance.client.channel('matches_channel');

      // Listen for INSERT events (new matches)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'matches',
        callback: (payload) async {
          print('New match INSERT event received: ${payload.toString()}');
          _handleMatchEvent(payload.newRecord);
        },
      );

      // Listen for UPDATE events (match updates)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'matches',
        callback: (payload) async {
          print('Match UPDATE event received: ${payload.toString()}');
          _handleMatchEvent(payload.newRecord);
        },
      );

      // Subscribe to the channel
      _matchSubscription = channel.subscribe((status, error) {
        if (error != null) {
          print('Error subscribing to matches channel: $error');
        } else {
          print(
            'Successfully subscribed to matches channel with status: $status',
          );
        }
      });

      print('Real-time subscription set up successfully');
    } catch (e) {
      print('Error subscribing to matches: $e');

      // Try to resubscribe after a delay if there was an error
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _matchSubscription == null) {
          print('Attempting to resubscribe to matches after error');
          _subscribeToMatches();
        }
      });
    }
  }

  // Helper method to handle match events
  void _handleMatchEvent(Map<String, dynamic> matchRecord) async {
    if (!mounted) return;

    // Check if this match involves the current user
    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId == null) {
      print('Current user ID is null, cannot process match event');
      return;
    }

    String? matchedProfileId;
    if (matchRecord['user_id1'] == currentUserId) {
      // Current user is user1
      matchedProfileId = matchRecord['user_id2'];
      print('Current user is user1, matched with user2: $matchedProfileId');
    } else if (matchRecord['user_id2'] == currentUserId) {
      // Current user is user2
      matchedProfileId = matchRecord['user_id1'];
      print('Current user is user2, matched with user1: $matchedProfileId');
    } else {
      print('Match does not involve current user: $currentUserId');
      return;
    }

    // Check if this match has already been shown
    final matchId = matchRecord['id'];

    // First check if it's in our local shown matches set
    if (_shownMatchIds.contains(matchId)) {
      print('Match $matchId is in local shown matches set, skipping dialog');
      return;
    }

    // Then double-check with the server to be sure
    final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
    if (hasBeenSeen) {
      print(
        'Match $matchId has been seen according to server, adding to local set',
      );
      await _addToShownMatchIds(matchId);
      return;
    }

    // Add this match to the shown matches set
    await _addToShownMatchIds(matchId);

    // Get the profile of the matched user
    if (matchedProfileId != null) {
      print('Fetching profile details for matched user: $matchedProfileId');
      final matchedProfile = await SupabaseService.getProfileById(
        matchedProfileId,
      );

      if (matchedProfile != null && mounted) {
        print('Showing match dialog for: ${matchedProfile['name']}');

        // Add match_id to the profile data for the dialog
        final profileWithMatchId = Map<String, dynamic>.from(matchedProfile);
        profileWithMatchId['match_id'] = matchId;

        // Show match dialog with animation
        _showEnhancedMatchDialog(profileWithMatchId);

        // Mark the match as seen
        SupabaseService.markMatchAsSeen(matchId).then((_) {
          print('Marked match as seen: $matchId');
        });
      } else {
        print('Failed to fetch profile for matched user: $matchedProfileId');
      }
    }
  }

  // Check for unseen matches when returning to the screen
  Future<void> _checkForUnseenMatches() async {
    try {
      print('Checking for unseen matches on app return/startup');

      // Set flag to false to avoid checking multiple times
      _needToCheckUnseenMatches = false;

      // First, manually check for matches that might have been missed
      print('Running manual match check first');
      final manualMatches = await SupabaseService.checkForManualMatches();
      if (manualMatches.isNotEmpty) {
        print('Found ${manualMatches.length} new matches from manual check');

        // Find the first match that hasn't been shown yet
        Map<String, dynamic>? matchToShow;
        for (final match in manualMatches) {
          final matchId = match['match']['id'];

          // First check if it's in our local shown matches set
          if (_shownMatchIds.contains(matchId)) {
            print('Match $matchId is in local shown matches set, skipping');
            continue;
          }

          // Then double-check with the server to be sure
          final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
          if (hasBeenSeen) {
            print(
              'Match $matchId has been seen according to server, adding to local set',
            );
            await _addToShownMatchIds(matchId);
            continue;
          }

          // If we get here, the match hasn't been shown yet
          matchToShow = match;
          await _addToShownMatchIds(matchId);
          break;
        }

        if (matchToShow != null) {
          print('Showing match dialog for: ${matchToShow['profile']['name']}');

          // Add match_id to the profile data for the dialog
          final matchProfile = Map<String, dynamic>.from(
            matchToShow['profile'],
          );
          matchProfile['match_id'] = matchToShow['match']['id'];

          _showEnhancedMatchDialog(matchProfile);

          // Mark the match as seen
          await SupabaseService.markMatchAsSeen(matchToShow['match']['id']);
          print('Marked match as seen: ${matchToShow['match']['id']}');

          // If there are more manual matches, set the flag to check again later
          if (manualMatches.length > 1) {
            print(
              'There are more manual matches (${manualMatches.length - 1}), will check again later',
            );
            _needToCheckUnseenMatches = true;
            return;
          }
        } else {
          print('All manual matches have already been shown');
        }
      } else {
        print('No new matches found from manual check');
      }

      // Then check for any unseen matches
      final unseenMatches = await SupabaseService.getUnseenMatches();
      print('Found ${unseenMatches.length} unseen matches');

      if (unseenMatches.isNotEmpty && mounted) {
        // Find the first unseen match that hasn't been shown yet
        Map<String, dynamic>? matchToShow;
        for (final match in unseenMatches) {
          final matchId = match['match']['id'];

          // First check if it's in our local shown matches set
          if (_shownMatchIds.contains(matchId)) {
            print('Match $matchId is in local shown matches set, skipping');
            continue;
          }

          // Then double-check with the server to be sure
          final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
          if (hasBeenSeen) {
            print(
              'Match $matchId has been seen according to server, adding to local set',
            );
            await _addToShownMatchIds(matchId);
            continue;
          }

          // If we get here, the match hasn't been shown yet
          matchToShow = match;
          await _addToShownMatchIds(matchId);
          break;
        }

        if (matchToShow != null) {
          print('Showing match dialog for: ${matchToShow['profile']['name']}');

          // Add match_id to the profile data for the dialog
          final matchProfile = Map<String, dynamic>.from(
            matchToShow['profile'],
          );
          matchProfile['match_id'] = matchToShow['match']['id'];

          _showEnhancedMatchDialog(matchProfile);

          // Mark the match as seen
          await SupabaseService.markMatchAsSeen(matchToShow['match']['id']);
          print('Marked match as seen: ${matchToShow['match']['id']}');

          // If there are more unseen matches, set the flag to check again later
          if (unseenMatches.length > 1) {
            print(
              'There are more unseen matches (${unseenMatches.length - 1}), will check again later',
            );
            _needToCheckUnseenMatches = true;
          }
        } else {
          print('All unseen matches have already been shown');
        }
      } else {
        print('No unseen matches found');
      }
    } catch (e) {
      print('Error checking for unseen matches: $e');
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

      // Always check for unseen matches, even when refreshing the Explore view
      // This ensures users don't miss any matches
      _needToCheckUnseenMatches = true;

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
          print(
            'Checking for match after liking profile: ${swipedProfile['name']}',
          );

          // Add a small delay to allow the database to process the swipe
          // This helps ensure the real-time subscription has time to detect the match
          await Future.delayed(const Duration(milliseconds: 300));

          final isMatch = await SupabaseService.checkForMatch(swipedProfileId);
          print('Match check result: ${isMatch ? "MATCH!" : "No match"}');

          if (isMatch && mounted) {
            print('Showing match dialog for: ${swipedProfile['name']}');

            // Get the match record to get the match ID
            final matchRecords = await SupabaseService.getMatchWithProfile(
              swipedProfileId,
            );
            if (matchRecords.isNotEmpty) {
              final matchId = matchRecords.first['match']['id'];

              // Check if this match has already been shown
              if (_shownMatchIds.contains(matchId)) {
                print('Match $matchId has already been shown, skipping dialog');
              } else {
                // Double-check with the server to be sure
                final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(
                  matchId,
                );
                if (hasBeenSeen) {
                  print(
                    'Match $matchId has been seen according to server, adding to local set',
                  );
                  await _addToShownMatchIds(matchId);
                } else {
                  // Add match_id to the profile data for the dialog
                  final matchProfile = Map<String, dynamic>.from(swipedProfile);
                  matchProfile['match_id'] = matchId;

                  // Add this match to the shown matches set
                  await _addToShownMatchIds(matchId);

                  // Show enhanced match dialog with animation
                  _showEnhancedMatchDialog(matchProfile);

                  // Mark the match as seen
                  await SupabaseService.markMatchAsSeen(matchId);
                }
              }
            } else {
              // Fallback if we can't find the match record
              _showEnhancedMatchDialog(swipedProfile);
            }
          } else {
            // Even if no immediate match was found, check for any unseen matches
            // This ensures we catch matches from previous sessions or offline periods
            print('No immediate match found, checking for any unseen matches');
            _needToCheckUnseenMatches = true;
            _checkForUnseenMatches();
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

            // Add new profiles directly since there are never duplicates
            print('Adding ${newProfiles.length} new profiles to the stack');
            _profiles.addAll(newProfiles);

            // Update persisted profiles
            _persistedProfiles = List.from(_profiles);

            // Update batch parameters
            _currentBatchOffset += newProfiles.length;
            // If we got fewer profiles than the batch size, there are no more profiles
            _hasMoreProfiles = newProfiles.length == _batchSize;
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

  // Enhanced match dialog with animation
  void _showEnhancedMatchDialog(Map<String, dynamic> matchedProfile) {
    // Add match ID to the set of shown matches if available
    if (matchedProfile['match_id'] != null) {
      _addToShownMatchIds(matchedProfile['match_id']);
    }

    // Start confetti animation
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder:
          (context) => Stack(
            children: [
              // Confetti effect
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.2,
                  shouldLoop: false,
                  colors: const [
                    Colors.red,
                    Colors.pink,
                    Colors.purple,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                  ],
                ),
              ),
              // Match dialog
              AlertDialog(
                title: ShaderMask(
                  shaderCallback:
                      (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    '${matchedProfile['name']} wants to see you!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors
                              .white, // This color is used as the base for the gradient
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile picture
                    if (matchedProfile['profile_picture_url'] != null)
                      Container(
                        width: 126, // Slightly larger to account for the border
                        height:
                            126, // Slightly larger to account for the border
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(
                                  matchedProfile['profile_picture_url'],
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 126, // Slightly larger to account for the border
                        height:
                            126, // Slightly larger to account for the border
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'We set up a date for you,\nHave fun!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Stop confetti when dialog is closed
                        _confettiController.stop();

                        // Get the match ID before closing the dialog
                        final matchId = matchedProfile['match_id'];
                        print(
                          'MATCH DEBUG: All right button clicked, matchId: $matchId',
                        );

                        // Close the dialog immediately
                        Navigator.of(context).pop();

                        // Mark the match as seen if we have a match ID (do this after dialog is closed)
                        if (matchId != null) {
                          print(
                            'MATCH DEBUG: Marking match as seen from dialog button: $matchId',
                          );

                          // Use a microtask to ensure this runs after the dialog is closed
                          Future.microtask(() async {
                            try {
                              print(
                                'MATCH DEBUG: Starting microtask for match: $matchId',
                              );
                              await SupabaseService.markMatchAsSeen(matchId);
                              print(
                                'MATCH DEBUG: Successfully marked match as seen: $matchId',
                              );

                              // Verify the match was marked as seen
                              await _verifyMatchSeenStatus(matchId);

                              // Schedule a meetup for this match
                              print(
                                'MATCH DEBUG: Scheduling meetup for match: $matchId',
                              );
                              final success =
                                  await SupabaseService.scheduleMeetup(matchId);

                              print(
                                'MATCH DEBUG: Meetup scheduling result: $success',
                              );

                              if (success) {
                                print(
                                  'MATCH DEBUG: Meetup scheduled successfully',
                                );

                                // Check for upcoming meetups to display the meetup view
                                print(
                                  'MATCH DEBUG: Checking for upcoming meetups after successful scheduling',
                                );
                                await _checkForUpcomingMeetup();

                                print(
                                  'MATCH DEBUG: After _checkForUpcomingMeetup, _upcomingMeetup is ${_upcomingMeetup != null ? "not null" : "null"}',
                                );

                                // Force a UI refresh to ensure the meetup view is shown
                                if (mounted) {
                                  print(
                                    'MATCH DEBUG: Forcing UI refresh to show meetup view',
                                  );
                                  setState(() {
                                    // This empty setState will trigger a rebuild
                                  });

                                  // Add a delayed second check to ensure the meetup is loaded
                                  Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () {
                                      if (mounted) {
                                        print(
                                          'MATCH DEBUG: Performing delayed meetup check',
                                        );
                                        _checkForUpcomingMeetup().then((_) {
                                          print(
                                            'MATCH DEBUG: After delayed check, upcomingMeetup is ${_upcomingMeetup != null ? "not null" : "null"}',
                                          );

                                          // Force another UI refresh
                                          if (mounted) {
                                            print(
                                              'MATCH DEBUG: Forcing another UI refresh',
                                            );
                                            setState(() {});

                                            // Debug the view state
                                            _debugMeetupViewState();
                                          }
                                        });
                                      }
                                    },
                                  );
                                }
                              } else {
                                // Meetup scheduling failed
                                print('MATCH DEBUG: Meetup scheduling failed');

                                if (mounted) {
                                  // Show a message to the user
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'We couldn\'t find a suitable place for your meetup. You can still chat with your match!',
                                      ),
                                      duration: Duration(seconds: 4),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );

                                  // Refresh the UI to show the swipe stack
                                  setState(() {
                                    // This empty setState will trigger a rebuild
                                  });

                                  // Reload profiles if needed
                                  if (_profiles.isEmpty) {
                                    _initializeExplore();
                                  }
                                }
                              }
                            } catch (error) {
                              print(
                                'Error marking match as seen or scheduling meetup: $error',
                              );

                              // Show a toast to inform the user
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'We\'ll remember you\'ve seen this match!',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          });
                        } else {
                          print(
                            'No match_id found in profile data, cannot mark as seen',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'All right!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                actionsAlignment: MainAxisAlignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                backgroundColor: Colors.white,
                elevation: 10,
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

    // Check if we have an upcoming meetup
    final bool hasUpcomingMeetup = _upcomingMeetup != null;

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
          !hasUpcomingMeetup && // Only fetch more if no upcoming meetup
          mounted) {
        // Use a post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchMoreProfiles();
        });
      }
    });

    print('Building ExploreScreen with $profileCount profiles');
    if (hasUpcomingMeetup) {
      print('Building ExploreScreen with upcoming meetup');
    }

    return Scaffold(
      // Removing the app bar for a cleaner, more immersive experience
      body: SafeArea(
        child:
            _isLoading || _isReturningToScreen
                ? const Center(child: CircularProgressIndicator())
                // If we have an upcoming meetup, show it instead of profiles
                : hasUpcomingMeetup
                ? _buildUpcomingMeetupView()
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
                    // Debug button in the top-left corner (only in debug mode)
                    if (const bool.fromEnvironment('dart.vm.product') == false)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: FloatingActionButton(
                          mini: true,
                          heroTag: 'debug',
                          onPressed: () {
                            _debugTestSubscription();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Testing real-time subscription...',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          backgroundColor: Colors.grey[300],
                          child: const Icon(
                            Icons.bug_report,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    // Add the test button
                    _buildTestButton(),
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
                // Clear shown matches set when swipes are cleared
                await _ExploreScreenState.clearShownMatches();
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

  // Start periodic check for subscription health
  void _startPeriodicSubscriptionCheck() {
    // Cancel any existing timer
    _subscriptionCheckTimer?.cancel();

    // Check subscription every 30 seconds
    _subscriptionCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        print('Performing periodic subscription health check');

        // If subscription is null, resubscribe
        if (_matchSubscription == null) {
          print('Match subscription is null, resubscribing');
          _subscribeToMatches();
        } else {
          // For safety, always resubscribe periodically to ensure a fresh connection
          print('Refreshing match subscription for reliability');
          _subscribeToMatches();
        }

        // Only check for unseen matches if the flag is set
        if (_needToCheckUnseenMatches) {
          print('Checking for unseen matches from periodic check');
          _checkForUnseenMatches();
        } else {
          print('Skipping unseen matches check from periodic check');
        }
      }
    });
  }

  // Debug method to test the real-time subscription
  void _debugTestSubscription() async {
    print('===== REAL-TIME SUBSCRIPTION DEBUG =====');

    // Show a dialog to the user with debugging options
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Real-time Debug Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose a debugging action:'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetRealtimeConnection();
                  },
                  child: const Text('Reset Realtime Connection'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _testManualMatchCreation();
                  },
                  child: const Text('Create Test Match'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _checkRLSPolicies();
                  },
                  child: const Text('Check RLS Policies'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Reset the realtime connection
  void _resetRealtimeConnection() {
    print('Resetting realtime connection...');

    // Disconnect realtime
    try {
      print('Disconnecting realtime...');
      Supabase.instance.client.realtime.disconnect();

      // Wait a moment before reconnecting
      Future.delayed(const Duration(seconds: 1), () {
        print('Reconnecting realtime...');
        // ignore: invalid_use_of_internal_member
        Supabase.instance.client.realtime.connect();

        // Resubscribe to matches
        Future.delayed(const Duration(seconds: 1), () {
          print('Resubscribing to matches...');
          _subscribeToMatches();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Realtime connection reset and resubscribed'),
              duration: Duration(seconds: 3),
            ),
          );
        });
      });
    } catch (e) {
      print('Error resetting realtime connection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Test method to manually create a match record
  Future<void> _testManualMatchCreation() async {
    try {
      print('Testing manual match creation to verify real-time events');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating test match...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Get the current user ID
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        print('ERROR: Current user ID is null, cannot test match creation');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Try to create a test match directly
      final testMatch = await SupabaseService.createTestMatch();

      if (testMatch != null) {
        print('Test match created successfully: $testMatch');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test match created! Check logs for details'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to create test match');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create test match'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error in test match creation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Check RLS policies
  Future<void> _checkRLSPolicies() async {
    try {
      print('Checking RLS policies for matches table...');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking RLS policies...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Try to get all matches (this will likely fail if RLS is restricting access)
      try {
        final allMatches =
            await Supabase.instance.client.from('matches').select();
        print(
          'Successfully retrieved ${allMatches.length} matches - RLS might be too permissive',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Retrieved ${allMatches.length} matches - RLS might be too permissive',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        print('Could not retrieve all matches (expected with RLS): $e');
      }

      // Try to get matches for the current user (this should succeed)
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != null) {
        try {
          final userMatches = await Supabase.instance.client
              .from('matches')
              .select()
              .or('user_id1.eq.$currentUserId,user_id2.eq.$currentUserId');

          print(
            'Successfully retrieved ${userMatches.length} matches for current user',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found ${userMatches.length} matches for your user',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Check if realtime is enabled for this table
          print('Checking if realtime is enabled for matches table...');
          print(
            'Current realtime status: ${Supabase.instance.client.realtime.isConnected ? "Connected ✓" : "Disconnected ✗"}',
          );

          // Show a message with instructions for the user
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Supabase Configuration Check'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Please check your Supabase configuration:'),
                      const SizedBox(height: 8),
                      const Text('1. Realtime is enabled for the project'),
                      const Text(
                        '2. Realtime is enabled for the "matches" table',
                      ),
                      const Text(
                        '3. RLS policies allow the current user to SELECT from matches',
                      ),
                      const Text('4. Database webhook is configured correctly'),
                      const SizedBox(height: 16),
                      const Text('Current status:'),
                      Text(
                        '• Realtime connection: ${Supabase.instance.client.realtime.isConnected ? "Connected ✓" : "Disconnected ✗"}',
                      ),
                      Text(
                        '• User matches found: ${userMatches.length > 0 ? "Yes ✓" : "No ✗"}',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        } catch (e) {
          print('Error retrieving matches for current user: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error checking RLS policies: $e');
    }
  }

  // Load shown match IDs from SharedPreferences
  Future<void> _loadShownMatchIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> storedIds =
          prefs.getStringList(_shownMatchIdsKey) ?? [];

      setState(() {
        _shownMatchIds = Set<String>.from(storedIds);
      });

      print('Loaded ${_shownMatchIds.length} shown match IDs from storage');
    } catch (e) {
      print('Error loading shown match IDs: $e');
    }
  }

  // Save shown match IDs to SharedPreferences
  Future<void> _saveShownMatchIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_shownMatchIdsKey, _shownMatchIds.toList());
      print('Saved ${_shownMatchIds.length} shown match IDs to storage');
    } catch (e) {
      print('Error saving shown match IDs: $e');
    }
  }

  // Add a match ID to the shown matches set and save to storage
  Future<void> _addToShownMatchIds(String matchId) async {
    if (!_shownMatchIds.contains(matchId)) {
      setState(() {
        _shownMatchIds.add(matchId);
      });
      await _saveShownMatchIds();
      print('Added match ID $matchId to shown matches and saved to storage');
    }
  }

  // Clear shown match IDs from memory and storage
  static Future<void> clearShownMatches() async {
    _shownMatchIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shownMatchIdsKey);
      print('Cleared shown matches from storage');
    } catch (e) {
      print('Error clearing shown match IDs: $e');
    }
  }

  // Add a helper method to verify the match seen status
  Future<void> _verifyMatchSeenStatus(String matchId) async {
    try {
      // Use the hasMatchBeenSeen method to check if the match has been seen
      final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);

      print('Verification - Match ID: $matchId, Has been seen: $hasBeenSeen');

      if (!hasBeenSeen) {
        print(
          'WARNING: Match was not properly marked as seen after verification',
        );

        // Try to mark it as seen again
        print('Attempting to mark match as seen again');
        await SupabaseService.markMatchAsSeen(matchId);
      } else {
        print('Verification successful: Match was properly marked as seen');
      }
    } catch (e) {
      print('Error verifying match seen status: $e');
    }
  }

  // Add method to check for upcoming meetups
  Future<void> _checkForUpcomingMeetup() async {
    if (_isCheckingMeetup) {
      print('MEETUP DEBUG: Already checking for meetups, skipping');
      return;
    }

    print('MEETUP DEBUG: Starting to check for upcoming meetups');
    setState(() {
      _isCheckingMeetup = true;
    });

    try {
      print('MEETUP DEBUG: Checking for upcoming meetups');

      // First check if any meetups have passed and update their status
      print('MEETUP DEBUG: Checking and updating passed meetup status');
      final statusUpdated = await SupabaseService.checkAndUpdateMeetupStatus();
      print(
        'MEETUP DEBUG: Meetup status update result: ${statusUpdated ? "updated some meetups" : "no updates needed"}',
      );

      // Then get the upcoming meetup if any
      print('MEETUP DEBUG: Fetching upcoming meetup from Supabase');
      final meetup = await SupabaseService.getUpcomingMeetup();
      print(
        'MEETUP DEBUG: Upcoming meetup fetch result: ${meetup != null ? "found meetup" : "no meetup found"}',
      );

      if (mounted) {
        print(
          'MEETUP DEBUG: Setting upcoming meetup state: ${meetup != null ? "not null" : "null"}',
        );

        // Print more details about the meetup if it exists
        if (meetup != null) {
          print('MEETUP DEBUG: Meetup details:');
          print('  Match ID: ${meetup['match']['id']}');
          print('  Place ID: ${meetup['match']['place_id']}');
          print('  Meetup Time: ${meetup['match']['meetup_time']}');
          print(
            '  Place: ${meetup['place'] != null ? meetup['place']['name'] : "null"}',
          );
          print(
            '  Other User: ${meetup['other_user'] != null ? meetup['other_user']['name'] : "null"}',
          );
        }

        setState(() {
          _upcomingMeetup = meetup;
          _isCheckingMeetup = false;
        });

        if (meetup != null) {
          print(
            'MEETUP DEBUG: Found upcoming meetup: ${meetup['match']['id']}',
          );
          print(
            'MEETUP DEBUG: Meetup details: place_id=${meetup['match']['place_id']}, time=${meetup['match']['meetup_time']}',
          );

          // If we have an upcoming meetup, schedule a meetup for it if not already scheduled
          if (meetup['match']['place_id'] == null ||
              meetup['match']['meetup_time'] == null) {
            print('MEETUP DEBUG: Meetup needs scheduling, scheduling now...');
            final success = await SupabaseService.scheduleMeetup(
              meetup['match']['id'],
            );
            print('MEETUP DEBUG: Scheduling result: $success');

            // Refresh the meetup details
            print('MEETUP DEBUG: Refreshing meetup details after scheduling');
            _checkForUpcomingMeetup();
          } else {
            print(
              'MEETUP DEBUG: Meetup already has place and time, no need to schedule',
            );
          }
        } else {
          print('MEETUP DEBUG: No upcoming meetups found');
        }
      } else {
        print('MEETUP DEBUG: Widget not mounted, skipping state update');
      }
    } catch (e) {
      print('MEETUP DEBUG: Error checking for upcoming meetups: $e');
      if (mounted) {
        setState(() {
          _isCheckingMeetup = false;
        });
      }
    }
  }

  // Build the upcoming meetup view
  Widget _buildUpcomingMeetupView() {
    return MeetupView(
      meetup: _upcomingMeetup!,
      onCancelMeetup: _cancelMeetup,
      onReturnToSwiping: () {
        setState(() {
          _upcomingMeetup = null;
        });
        _initializeExplore();
      },
    );
  }

  // Add method to cancel a meetup
  Future<void> _cancelMeetup(String matchId) async {
    try {
      print('Cancelling meetup: $matchId');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelling meetup...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Cancel the meetup
      final success = await SupabaseService.cancelMeetup(matchId);

      if (success && mounted) {
        // Clear the upcoming meetup
        setState(() {
          _upcomingMeetup = null;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meetup cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the explore screen
        _initializeExplore();
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel meetup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error cancelling meetup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Add a test method to check if find_places_near_point is working
  Future<void> _testFindPlacesNearPoint() async {
    try {
      print('Testing find_places_near_point function');

      // Get current user profile to get location
      final userProfile = await SupabaseService.getUserProfile();
      if (userProfile == null) {
        print('Could not get user profile');
        return;
      }

      final double? userLat = userProfile['latitude'];
      final double? userLng = userProfile['longitude'];

      if (userLat == null || userLng == null) {
        print('User has no location data');
        return;
      }

      print('User location: $userLat, $userLng');

      // Call the function directly
      final result = await Supabase.instance.client.rpc(
        'find_places_near_point',
        params: {
          'lat': userLat,
          'lng': userLng,
          'max_distance': 10, // 10 km radius
          'limit_count': 5, // Get top 5 places
        },
      );

      print('find_places_near_point result: ${result.length} places found');

      if (result.isNotEmpty) {
        print('First place: ${result[0]['name']} at ${result[0]['address']}');
        print('Place availability: ${result[0]['availability']}');
      }
    } catch (e) {
      print('Error testing find_places_near_point: $e');
    }
  }

  // Add a test method to directly schedule a meetup
  Future<void> _testScheduleMeetup() async {
    try {
      print('Testing direct meetup scheduling');

      // First, create a test match
      final testMatch = await SupabaseService.createTestMatch();
      if (testMatch == null) {
        print('Could not create test match');
        return;
      }

      print('Created test match: ${testMatch['id']}');

      // Schedule a meetup for the test match
      final success = await SupabaseService.scheduleMeetup(testMatch['id']);

      if (success) {
        print('Test meetup scheduled successfully');

        // Check for upcoming meetups
        await _checkForUpcomingMeetup();

        // Force UI refresh
        if (mounted) {
          setState(() {});
        }
      } else {
        print('Failed to schedule test meetup');
      }
    } catch (e) {
      print('Error in test meetup scheduling: $e');
    }
  }

  // Add a debug method to query matches with meetups
  Future<void> _debugQueryMatchesWithMeetups() async {
    try {
      print('Debugging: Querying matches with meetups');

      final matches = await SupabaseService.debugQueryMatchesWithMeetups();

      if (matches.isEmpty) {
        print('No matches with meetups found');

        // Show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No matches with meetups found'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('Found ${matches.length} matches with meetups');

        // Show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${matches.length} matches with meetups'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error debugging matches with meetups: $e');
    }
  }

  // Add a debug method to check if the meetup view is being displayed correctly
  void _debugMeetupViewState() {
    print('Debugging meetup view state:');
    print(
      '  _upcomingMeetup: ${_upcomingMeetup != null ? "not null" : "null"}',
    );
    print('  hasProfiles: ${_profiles.isNotEmpty}');
    print('  _isLoading: $_isLoading');
    print('  _isReturningToScreen: $_isReturningToScreen');
    print('  _isCheckingMeetup: $_isCheckingMeetup');

    // Show a snackbar with the state
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meetup: ${_upcomingMeetup != null ? "YES" : "NO"}, Profiles: ${_profiles.length}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // If we have an upcoming meetup, print its details
    if (_upcomingMeetup != null) {
      final match = _upcomingMeetup!['match'];
      final place = _upcomingMeetup!['place'];
      print('  Match ID: ${match['id']}');
      print('  Place ID: ${match['place_id']}');
      print('  Place Name: ${place != null ? place['name'] : "null"}');
      print('  Meetup Time: ${match['meetup_time']}');
    }
  }

  // Add a method to directly create a test meetup
  Future<void> _testDirectMeetupCreation() async {
    try {
      print('Testing direct meetup creation');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating test meetup...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Create a test meetup directly
      final success = await SupabaseService.createTestMeetupDirectly();

      if (success) {
        print('Test meetup created successfully');

        // Check for upcoming meetups
        await _checkForUpcomingMeetup();

        // Force UI refresh
        if (mounted) {
          setState(() {});

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test meetup created successfully'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('Failed to create test meetup');

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create test meetup'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error creating test meetup: $e');
    }
  }

  // Test direct match update
  Future<void> _testDirectMatchUpdate() async {
    try {
      // First, get the most recent match
      final matches = await SupabaseService.debugQueryMatchesWithMeetups();

      if (matches.isEmpty) {
        // If no matches with meetups, create a test match
        print('No matches found, creating a test match first');
        final testMatch = await SupabaseService.createTestMatch();
        if (testMatch == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create test match'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Test updating the new match
        final success = await SupabaseService.testDirectMatchUpdate(
          testMatch['id'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully updated test match'
                  : 'Failed to update test match',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      } else {
        // Use the first match from the list
        final matchId = matches[0]['id'];
        print('Testing update on existing match: $matchId');

        final success = await SupabaseService.testDirectMatchUpdate(matchId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully updated existing match'
                  : 'Failed to update existing match',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }

      // Check for upcoming meetups after the update
      await _checkForUpcomingMeetup();

      // Force UI refresh
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error in test direct match update: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build test button with popup menu
  Widget _buildTestButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bug_report, color: Colors.white),
        ),
        onSelected: (value) async {
          switch (value) {
            case 'test_places':
              await _testFindPlacesNearPoint();
              break;
            case 'test_schedule':
              await _testScheduleMeetup();
              break;
            case 'test_check_meetup':
              await _checkForUpcomingMeetup();
              if (mounted) {
                setState(() {});
                _debugMeetupViewState();
              }
              break;
            case 'test_debug_matches':
              await _debugQueryMatchesWithMeetups();
              break;
            case 'test_debug_view':
              _debugMeetupViewState();
              break;
            case 'test_direct_meetup':
              await _testDirectMeetupCreation();
              break;
            case 'test_direct_update':
              await _testDirectMatchUpdate();
              break;
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'test_places',
                child: Text('Test Find Places'),
              ),
              const PopupMenuItem(
                value: 'test_schedule',
                child: Text('Test Schedule Meetup'),
              ),
              const PopupMenuItem(
                value: 'test_check_meetup',
                child: Text('Check for Upcoming Meetup'),
              ),
              const PopupMenuItem(
                value: 'test_debug_matches',
                child: Text('Debug Matches with Meetups'),
              ),
              const PopupMenuItem(
                value: 'test_debug_view',
                child: Text('Debug View State'),
              ),
              const PopupMenuItem(
                value: 'test_direct_meetup',
                child: Text('Create Test Meetup'),
              ),
              const PopupMenuItem(
                value: 'test_direct_update',
                child: Text('Test Direct Match Update'),
              ),
            ],
      ),
    );
  }
}
