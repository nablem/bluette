import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';

class MeetupView extends StatefulWidget {
  final Map<String, dynamic> meetup;
  final Function(String) onCancelMeetup;
  final VoidCallback onReturnToSwiping;

  const MeetupView({
    Key? key,
    required this.meetup,
    required this.onCancelMeetup,
    required this.onReturnToSwiping,
  }) : super(key: key);

  @override
  State<MeetupView> createState() => _MeetupViewState();
}

class _MeetupViewState extends State<MeetupView> with TickerProviderStateMixin {
  // Animation controllers for floating effect
  late AnimationController _currentUserAnimController;
  late AnimationController _otherUserAnimController;

  // Random offsets for floating animation
  final _random = math.Random();
  late double _currentUserOffsetX;
  late double _currentUserOffsetY;
  late double _otherUserOffsetX;
  late double _otherUserOffsetY;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers with faster animation for more conspicuous movement
    _currentUserAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500 + _random.nextInt(500)),
    );

    _otherUserAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500 + _random.nextInt(500)),
    );

    // Set random offsets for floating animation
    _setRandomOffsets();

    // Start animations
    _currentUserAnimController.repeat(reverse: true);
    _otherUserAnimController.repeat(reverse: true);

    // Add listeners to restart animations with new random values
    _currentUserAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _setRandomOffsets();
      }
    });

    _otherUserAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _setRandomOffsets();
      }
    });
  }

  void _setRandomOffsets() {
    // Larger random offsets for more conspicuous floating effect
    // Left profile moves mostly left/right and slightly up/down
    _currentUserOffsetX = (_random.nextDouble() * 50) - 25;
    _currentUserOffsetY = (_random.nextDouble() * 20) - 10;

    // Right profile moves mostly up/down and slightly left/right
    _otherUserOffsetX = (_random.nextDouble() * 20) - 10;
    _otherUserOffsetY = (_random.nextDouble() * 50) - 25;
  }

  @override
  void dispose() {
    _currentUserAnimController.dispose();
    _otherUserAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.meetup['match'];
    final place = widget.meetup['place'];
    final otherUser = widget.meetup['other_user'];
    final currentUser = widget.meetup['current_user'];

    // Parse the meetup time from UTC
    final DateTime utcMeetupTime = DateTime.parse(match['meetup_time']);

    // Convert UTC time to local time
    final DateTime localMeetupTime = utcMeetupTime.toLocal();

    // Format the time as HH:MM
    final String formattedTime =
        '${localMeetupTime.hour.toString().padLeft(2, '0')}:${localMeetupTime.minute.toString().padLeft(2, '0')}';

    // Format the date as "Thursday, May 6th"
    final String formattedDate =
        DateFormat('EEEE, MMMM d').format(localMeetupTime) +
        _getDaySuffix(localMeetupTime.day);

    // Check if the meetup has passed (more than 1 hour after the meetup time)
    final bool meetupPassed = DateTime.now().isAfter(
      localMeetupTime.add(const Duration(hours: 1)),
    );

    // Get screen height to calculate top third
    final screenHeight = MediaQuery.of(context).size.height;
    final topThirdHeight =
        screenHeight / 2.2; // Slightly reduced to avoid overflow

    // Define gradient colors for consistency
    final gradientColors = [Colors.purple.shade300, Colors.blue.shade300];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spacer to push content down a bit
          SizedBox(height: topThirdHeight * 0.1),

          // New header text positioned lower with gradient username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTheme.headingStyle.copyWith(
                  fontSize: 22,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text:
                        meetupPassed
                            ? "You recently met "
                            : "You're about to meet ",
                  ),
                  TextSpan(
                    text: otherUser['name'] ?? 'someone',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      foreground:
                          Paint()
                            ..shader = LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(
                              const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile pictures floating in top half of screen with more space
          SizedBox(
            height: topThirdHeight,
            child: Stack(
              children: [
                // Current user profile picture with animation
                Positioned(
                  left:
                      MediaQuery.of(context).size.width *
                      0.1, // More to the left
                  top: topThirdHeight * 0.2,
                  child: AnimatedBuilder(
                    animation: _currentUserAnimController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _currentUserOffsetX *
                              _currentUserAnimController.value,
                          _currentUserOffsetY *
                              _currentUserAnimController.value,
                        ),
                        child: Container(
                          height: 180, // Reduced size to fix overflow
                          width: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0), // Border width
                            child: CircleAvatar(
                              radius: 86,
                              backgroundImage:
                                  currentUser['profile_picture_url'] != null
                                      ? NetworkImage(
                                        currentUser['profile_picture_url'],
                                      )
                                      : null,
                              child:
                                  currentUser['profile_picture_url'] == null
                                      ? const Icon(Icons.person, size: 80)
                                      : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Other user profile picture with animation
                Positioned(
                  right:
                      MediaQuery.of(context).size.width *
                      0.1, // More to the right
                  top: topThirdHeight * 0.4, // Lower position to avoid overlap
                  child: AnimatedBuilder(
                    animation: _otherUserAnimController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _otherUserOffsetX * _otherUserAnimController.value,
                          _otherUserOffsetY * _otherUserAnimController.value,
                        ),
                        child: Container(
                          height: 180, // Reduced size to fix overflow
                          width: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0), // Border width
                            child: CircleAvatar(
                              radius: 86,
                              backgroundImage:
                                  otherUser['profile_picture_url'] != null
                                      ? NetworkImage(
                                        otherUser['profile_picture_url'],
                                      )
                                      : null,
                              child:
                                  otherUser['profile_picture_url'] == null
                                      ? const Icon(Icons.person, size: 80)
                                      : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Spacer to push the card to the bottom
          const Spacer(),

          // Meetup details card (now at the bottom)
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place name
                      Row(
                        children: [
                          const Icon(Icons.place, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place['name'] ?? 'Unknown Place',
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Address
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Text(
                          place['address'] ?? 'No address available',
                          style: AppTheme.bodyStyle,
                        ),
                      ),

                      // Locality (new)
                      if (place['locality'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0, top: 4.0),
                          child: Text(
                            place['locality'],
                            style: AppTheme.bodyStyle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Date and Time
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedTime,
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Map link
                      if (place['google_maps_uri'] != null)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Open Google Maps link
                              final Uri url = Uri.parse(
                                place['google_maps_uri'],
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              } else {
                                print(
                                  'Could not launch ${place['google_maps_uri']}',
                                );
                              }
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Show on the map'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Cancel button in top right corner
                if (!meetupPassed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Cancel Meetup?'),
                                content: const Text(
                                  'Are you sure you want to cancel this meetup?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onCancelMeetup(match['id']);
                                    },
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Return to swiping button (only shown if meetup has passed)
          if (meetupPassed)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                onPressed: widget.onReturnToSwiping,
                icon: const Icon(Icons.refresh),
                label: const Text('Return to Swiping'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get the day suffix (th, st, nd, rd)
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }

    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
