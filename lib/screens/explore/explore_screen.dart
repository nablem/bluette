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
import '../../l10n/app_localizations.dart';

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

  // Static set to track which matches have already been shown to the user
  static Set<String> _shownMatchIds = {};

  // Key for storing shown match IDs in SharedPreferences
  static const String _shownMatchIdsKey = 'shown_match_ids';

  // Add a flag to track if we're returning to the screen
  final bool _isReturningToScreen = false;

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
    _loadShownMatchIds().then((_) {});

    // Check for upcoming meetups
    _checkForUpcomingMeetup();

    // Check and update meetup status
    SupabaseService.checkAndUpdateMeetupStatus().then((_) {});

    // Always check location status first before proceeding with any other initialization
    _checkLocationStatusAndInitialize();

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

    // Ensure location permission is checked when the widget is built
    _ensureLocationPermission();

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
      // Always check location status when app resumes
      _checkLocationStatusChange();

      // Reload user profile to get the latest filter values
      if (_hasBeenInitialized) {
        _reloadUserProfile();
      }

      // Check for upcoming meetups
      _checkForUpcomingMeetup();

      // Ensure we have an active match subscription
      if (_matchSubscription == null) {
        _subscribeToMatches();
      } else {
        // For safety, resubscribe to ensure we have a fresh connection

        _subscribeToMatches();
      }

      // Always check for unseen matches when app resumes
      // Use a short delay to ensure the UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkForUnseenMatches();
        }
      });
    } else if (state == AppLifecycleState.paused) {}
  }

  // Subscribe to real-time match events
  void _subscribeToMatches() {
    try {
      // Clean up any existing subscription first
      if (_matchSubscription != null) {
        Supabase.instance.client.removeChannel(_matchSubscription!);
        _matchSubscription = null;
      }

      // Enable real-time for the client
      try {
        // ignore: invalid_use_of_internal_member
        Supabase.instance.client.realtime.connect();
      } catch (e) {
        // Ignore errors
      }

      final channel = Supabase.instance.client.channel('matches_channel');

      // Listen for INSERT events (new matches)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'matches',
        callback: (payload) async {
          _handleMatchEvent(payload.newRecord);
        },
      );

      // Listen for UPDATE events (match updates)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'matches',
        callback: (payload) async {
          _handleMatchEvent(payload.newRecord);
        },
      );

      // Subscribe to the channel
      _matchSubscription = channel.subscribe((status, error) {
        if (error != null) {
        } else {}
      });
    } catch (e) {
      // Try to resubscribe after a delay if there was an error
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _matchSubscription == null) {
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
      return;
    }

    String? matchedProfileId;
    if (matchRecord['user_id1'] == currentUserId) {
      // Current user is user1
      matchedProfileId = matchRecord['user_id2'];
    } else if (matchRecord['user_id2'] == currentUserId) {
      // Current user is user2
      matchedProfileId = matchRecord['user_id1'];
    } else {
      return;
    }

    // Check if this match has already been shown
    final matchId = matchRecord['id'];

    // First check if it's in our local shown matches set
    if (_shownMatchIds.contains(matchId)) {
      return;
    }

    // Then double-check with the server to be sure
    final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
    if (hasBeenSeen) {
      await _addToShownMatchIds(matchId);
      return;
    }

    // Add this match to the shown matches set
    await _addToShownMatchIds(matchId);

    // Get the profile of the matched user
    if (matchedProfileId != null) {
      final matchedProfile = await SupabaseService.getProfileById(
        matchedProfileId,
      );

      if (matchedProfile != null && mounted) {
        // Add match_id to the profile data for the dialog
        final profileWithMatchId = Map<String, dynamic>.from(matchedProfile);
        profileWithMatchId['match_id'] = matchId;

        // Show match dialog with animation
        _showEnhancedMatchDialog(profileWithMatchId);

        // Mark the match as seen
        SupabaseService.markMatchAsSeen(matchId).then((_) {});
      } else {}
    }
  }

  // Check for unseen matches when returning to the screen
  Future<void> _checkForUnseenMatches() async {
    try {
      // Set flag to false to avoid checking multiple times
      _needToCheckUnseenMatches = false;

      // First, manually check for matches that might have been missed

      final manualMatches = await SupabaseService.checkForManualMatches();
      if (manualMatches.isNotEmpty) {
        // Find the first match that hasn't been shown yet
        Map<String, dynamic>? matchToShow;
        for (final match in manualMatches) {
          final matchId = match['match']['id'];

          // First check if it's in our local shown matches set
          if (_shownMatchIds.contains(matchId)) {
            continue;
          }

          // Then double-check with the server to be sure
          final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
          if (hasBeenSeen) {
            await _addToShownMatchIds(matchId);
            continue;
          }

          // If we get here, the match hasn't been shown yet
          matchToShow = match;
          await _addToShownMatchIds(matchId);
          break;
        }

        if (matchToShow != null) {
          // Add match_id to the profile data for the dialog
          final matchProfile = Map<String, dynamic>.from(
            matchToShow['profile'],
          );
          matchProfile['match_id'] = matchToShow['match']['id'];

          _showEnhancedMatchDialog(matchProfile);

          // Mark the match as seen
          await SupabaseService.markMatchAsSeen(matchToShow['match']['id']);

          // If there are more manual matches, set the flag to check again later
          if (manualMatches.length > 1) {
            _needToCheckUnseenMatches = true;
            return;
          }
        } else {}
      } else {}

      // Then check for any unseen matches
      final unseenMatches = await SupabaseService.getUnseenMatches();

      if (unseenMatches.isNotEmpty && mounted) {
        // Find the first unseen match that hasn't been shown yet
        Map<String, dynamic>? matchToShow;
        for (final match in unseenMatches) {
          final matchId = match['match']['id'];

          // First check if it's in our local shown matches set
          if (_shownMatchIds.contains(matchId)) {
            continue;
          }

          // Then double-check with the server to be sure
          final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);
          if (hasBeenSeen) {
            await _addToShownMatchIds(matchId);
            continue;
          }

          // If we get here, the match hasn't been shown yet
          matchToShow = match;
          await _addToShownMatchIds(matchId);
          break;
        }

        if (matchToShow != null) {
          // Add match_id to the profile data for the dialog
          final matchProfile = Map<String, dynamic>.from(
            matchToShow['profile'],
          );
          matchProfile['match_id'] = matchToShow['match']['id'];

          _showEnhancedMatchDialog(matchProfile);

          // Mark the match as seen
          await SupabaseService.markMatchAsSeen(matchToShow['match']['id']);

          // If there are more unseen matches, set the flag to check again later
          if (unseenMatches.length > 1) {
            _needToCheckUnseenMatches = true;
          }
        } else {}
      } else {}
    } catch (e) {
      // Ignore errors
    }
  }

  // Check if location permission status has changed
  Future<void> _checkLocationStatusChange() async {
    final locationStatus = await LocationService.checkLocationStatus();
    final isPermissionGranted =
        locationStatus == LocationStatus.permissionGranted;

    // If status changed, update state
    if (isPermissionGranted != _isLocationPermissionGranted) {
      setState(() {
        _isLocationPermissionGranted = isPermissionGranted;
        _locationStatus = locationStatus;
      });

      // If permission was granted, initialize explore
      if (isPermissionGranted) {
        if (_profiles.isEmpty) {
          _initializeExplore();
        }
      } else {
        // If permission was revoked, clear profiles
        setState(() {
          _profiles = [];
        });
      }
    }
  }

  Future<void> _checkLocationStatusAndInitialize() async {
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

      // Check current location status without requesting permission first
      final locationStatus = await LocationService.checkLocationStatus();

      // Update location status in state
      setState(() {
        _locationStatus = locationStatus;
      });

      // If permission is already granted, proceed
      if (locationStatus == LocationStatus.permissionGranted) {
        setState(() {
          _isLocationPermissionGranted = true;
          _isLoading = false;
        });

        // Initialize explore if permission is granted
        await _initializeExplore();
        return;
      }

      // If permission is not granted, request it
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

      if (isPermissionGranted) {
        // Only initialize explore if permission is granted
        await _initializeExplore();
      } else {
        // If we've been initialized before but lost permission, clear profiles
        if (_hasBeenInitialized) {
          setState(() {
            _profiles = [];
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
      });

      // Log the error for debugging
    }
  }

  Future<void> _initializeExplore() async {
    // Ensure location permission is granted before initializing
    if (!_isLocationPermissionGranted) {
      await _checkLocationStatusAndInitialize();
      return;
    }

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
      if (!locationUpdated) {}

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
        });
      }

      // Log if no profiles were found
      if (profiles.isEmpty) {
        // If we didn't get any profiles but there might be more, try to fetch more
        if (_hasMoreProfiles) {
          // Use a short delay to avoid state conflicts
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _fetchMoreProfiles();
            }
          });
        } else {
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
          // Add a small delay to allow the database to process the swipe
          // This helps ensure the real-time subscription has time to detect the match
          await Future.delayed(const Duration(milliseconds: 300));

          final isMatch = await SupabaseService.checkForMatch(swipedProfileId);

          if (isMatch && mounted) {
            // Get the match record to get the match ID
            final matchRecords = await SupabaseService.getMatchWithProfile(
              swipedProfileId,
            );
            if (matchRecords.isNotEmpty) {
              final matchId = matchRecords.first['match']['id'];

              // Check if this match has already been shown
              if (_shownMatchIds.contains(matchId)) {
              } else {
                // Double-check with the server to be sure
                final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(
                  matchId,
                );
                if (hasBeenSeen) {
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
            }
          });
        }

        // Fetch more profiles when we're down to the last 3
        // This ensures we always have profiles ready before the user runs out
        if (mounted && _profiles.length <= 3 && _hasMoreProfiles) {
          await _fetchMoreProfiles();
        }
      } catch (e) {
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

    // Ensure location permission is granted before fetching profiles
    if (!_isLocationPermissionGranted) {
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

            _profiles.addAll(newProfiles);

            // Update batch parameters
            _currentBatchOffset += newProfiles.length;
            // If we got fewer profiles than the batch size, there are no more profiles
            _hasMoreProfiles = newProfiles.length == _batchSize;
          });
        } else {
          // No profiles returned means we've reached the end
          setState(() {
            _hasMoreProfiles = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
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

    final l10n = AppLocalizations.of(context)!;

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
                    l10n.wantsToSeeYou(matchedProfile['name']),
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
                    Text(
                      l10n.weSetUpDate,
                      style: const TextStyle(
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

                        // Close the dialog immediately
                        Navigator.of(context).pop();

                        // Mark the match as seen if we have a match ID (do this after dialog is closed)
                        if (matchId != null) {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          // Use a microtask to ensure this runs after the dialog is closed
                          Future.microtask(() async {
                            if (!mounted) return;
                            try {
                              await SupabaseService.markMatchAsSeen(matchId);
                              await _verifyMatchSeenStatus(matchId);
                              final success =
                                  await SupabaseService.scheduleMeetup(matchId);

                              if (success) {
                                await _checkForUpcomingMeetup();
                                if (mounted) {
                                  setState(() {});
                                  Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () {
                                      if (mounted) {
                                        _checkForUpcomingMeetup().then((_) {
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        });
                                      }
                                    },
                                  );
                                }
                              } else {
                                if (mounted) {
                                  setState(() {});
                                  if (_profiles.isEmpty) {
                                    _initializeExplore();
                                  }
                                }
                              }
                            } catch (error) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.weRememberSeen),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          });
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
                      child: Text(
                        l10n.allRight,
                        style: const TextStyle(
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
          _isLocationPermissionGranted && // Only fetch if location permission is granted
          mounted) {
        // Use a post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchMoreProfiles();
        });
      }
    });

    if (hasUpcomingMeetup) {}

    return Scaffold(
      // Removing the app bar for a cleaner, more immersive experience
      body: SafeArea(
        child:
            _isLoading || _isReturningToScreen
                ? const Center(child: CircularProgressIndicator())
                // If we have an upcoming meetup, show it instead of profiles
                : hasUpcomingMeetup
                ? _buildUpcomingMeetupView()
                // Always check location permission before showing profiles
                : !_isLocationPermissionGranted
                ? _buildLocationPermissionRequired()
                // If we have profiles, show them
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
                                  return const SizedBox.shrink();
                                }

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
                // Only show network error if we have no profiles
                : _errorMessage != null && isNetworkError
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorMessageWidget(
                        message: _errorMessage!,
                        onRetry: _checkLocationStatusAndInitialize,
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
              onPressed: _checkLocationStatusAndInitialize,
              child: const Text('Grant Permission'),
            )
          // Otherwise show as ElevatedButton with the same style as the other buttons
          else
            ElevatedButton(
              onPressed: _checkLocationStatusAndInitialize,
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
              onRetry: _checkLocationStatusAndInitialize,
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
      }
    } catch (e) {
      // Ignore errors
    }
  }

  // Start periodic check for subscription health
  void _startPeriodicSubscriptionCheck() {
    // Cancel any existing timer
    _subscriptionCheckTimer?.cancel();

    // Check subscription every 30 seconds
    _subscriptionCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        // If subscription is null, resubscribe
        if (_matchSubscription == null) {
          _subscribeToMatches();
        } else {
          // For safety, always resubscribe periodically to ensure a fresh connection

          _subscribeToMatches();
        }

        // Only check for unseen matches if the flag is set
        if (_needToCheckUnseenMatches) {
          _checkForUnseenMatches();
        } else {}
      }
    });
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
    } catch (e) {
      // Ignore errors
    }
  }

  // Save shown match IDs to SharedPreferences
  Future<void> _saveShownMatchIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_shownMatchIdsKey, _shownMatchIds.toList());
    } catch (e) {
      // Ignore errors
    }
  }

  // Add a match ID to the shown matches set and save to storage
  Future<void> _addToShownMatchIds(String matchId) async {
    if (!_shownMatchIds.contains(matchId)) {
      setState(() {
        _shownMatchIds.add(matchId);
      });
      await _saveShownMatchIds();
    }
  }

  // Clear shown match IDs from memory and storage
  static Future<void> clearShownMatches() async {
    _shownMatchIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shownMatchIdsKey);
    } catch (e) {
      // Ignore errors
    }
  }

  // Add a helper method to verify the match seen status
  Future<void> _verifyMatchSeenStatus(String matchId) async {
    try {
      // Use the hasMatchBeenSeen method to check if the match has been seen
      final hasBeenSeen = await SupabaseService.hasMatchBeenSeen(matchId);

      if (!hasBeenSeen) {
        // Try to mark it as seen again

        await SupabaseService.markMatchAsSeen(matchId);
      } else {}
    } catch (e) {
      // Ignore errors
    }
  }

  // Add method to check for upcoming meetups
  Future<void> _checkForUpcomingMeetup() async {
    if (_isCheckingMeetup) {
      return;
    }

    setState(() {
      _isCheckingMeetup = true;
    });

    try {
      // Then get the upcoming meetup if any

      final meetup = await SupabaseService.getUpcomingMeetup();

      if (mounted) {
        // Print more details about the meetup if it exists
        if (meetup != null) {}

        setState(() {
          _upcomingMeetup = meetup;
          _isCheckingMeetup = false;
        });

        if (meetup != null) {
          // If we have an upcoming meetup, schedule a meetup for it if not already scheduled
          if (meetup['match']['place_id'] == null ||
              meetup['match']['meetup_time'] == null) {
            // Refresh the meetup details

            _checkForUpcomingMeetup();
          } else {}
        } else {}
      } else {}
    } catch (e) {
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
      // Cancel the meetup
      final success = await SupabaseService.cancelMeetup(matchId);

      if (success && mounted) {
        // Clear the upcoming meetup
        setState(() {
          _upcomingMeetup = null;
        });

        // Refresh the explore screen
        _initializeExplore();
      } else if (mounted) {
        // Error message removed
      }
    } catch (e) {
      // Error snackbar removed
    }
  }

  // Add a helper method to ensure location permission is checked before showing the swipe stack
  Future<void> _ensureLocationPermission() async {
    // If we already have permission, no need to check again
    if (_isLocationPermissionGranted) return;

    // Check current location status
    final locationStatus = await LocationService.checkLocationStatus();
    final isPermissionGranted =
        locationStatus == LocationStatus.permissionGranted;

    if (isPermissionGranted) {
      // Update state if permission is granted
      setState(() {
        _isLocationPermissionGranted = true;
        _locationStatus = locationStatus;
      });

      // Initialize explore if we don't have profiles
      if (_profiles.isEmpty) {
        await _initializeExplore();
      }
    } else {
      // If permission is not granted, clear profiles
      setState(() {
        _profiles = [];
      });
    }
  }
}
