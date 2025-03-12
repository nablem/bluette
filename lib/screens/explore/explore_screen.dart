import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../constants/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final CardSwiperController _cardController = CardSwiperController();
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeExplore();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _initializeExplore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update user location
      await LocationService.updateUserLocation();

      // Fetch profiles to swipe
      final profiles = await SupabaseService.getProfilesToSwipe();

      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });

      // Log if no profiles were found
      if (profiles.isEmpty) {
        print(
          'No profiles found to swipe. User might have swiped all available profiles.',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profiles: $e';
        _isLoading = false;
      });
    }
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

        // Remove the swiped profile from the local list
        if (mounted) {
          setState(() {
            _profiles.removeAt(index);
          });
        }

        // If liked, check for a match
        if (liked) {
          final isMatch = await SupabaseService.checkForMatch(swipedProfileId);
          if (isMatch && mounted) {
            // Show match dialog
            _showMatchDialog(swipedProfile);
          }
        }
      } catch (e) {
        print('Error recording swipe: $e');
      }
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

  @override
  Widget build(BuildContext context) {
    // Make sure we're showing the correct UI state
    final bool hasProfiles = _profiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeExplore,
            tooltip: 'Refresh profiles',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
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
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 80, color: Colors.grey),
                    const SizedBox(height: 20),
                    Text(
                      'No more profiles to show',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Try again later or adjust your preferences',
                      style: AppTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _initializeExplore,
                      child: const Text('Refresh'),
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
                              SnackBar(
                                content: Text('Error clearing swipes: $e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset All Swipes (Testing)'),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CardSwiper(
                        controller: _cardController,
                        cardsCount: _profiles.length,
                        onSwipe: (previousIndex, currentIndex, direction) {
                          final liked = direction == CardSwiperDirection.right;
                          _handleSwipe(previousIndex, liked);

                          // Check if we've run out of profiles
                          if (_profiles.isEmpty ||
                              currentIndex == null ||
                              currentIndex >= _profiles.length) {
                            // Delay the state update slightly to avoid conflicts with the swipe animation
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) {
                                setState(() {
                                  // This will trigger a rebuild and show the "No more profiles" view
                                });
                              }
                            });
                          }

                          return true;
                        },
                        numberOfCardsDisplayed:
                            _profiles.length < 3 ? _profiles.length : 3,
                        backCardOffset: const Offset(20, 20),
                        padding: const EdgeInsets.all(24.0),
                        cardBuilder: (context, index, _, __) {
                          if (index < 0 || index >= _profiles.length) {
                            return const SizedBox.shrink();
                          }
                          return ProfileCard(profile: _profiles[index]);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 20.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Dislike button
                        FloatingActionButton(
                          heroTag: 'dislike',
                          onPressed: () {
                            if (_profiles.isNotEmpty) {
                              _cardController.swipe(CardSwiperDirection.left);
                            }
                          },
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                        // Like button
                        FloatingActionButton(
                          heroTag: 'like',
                          onPressed: () {
                            if (_profiles.isNotEmpty) {
                              _cardController.swipe(CardSwiperDirection.right);
                            }
                          },
                          backgroundColor: AppTheme.primaryColor,
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
