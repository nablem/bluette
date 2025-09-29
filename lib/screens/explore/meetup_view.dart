import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../l10n/app_localizations.dart';

class MeetupView extends StatefulWidget {
  final Map<String, dynamic> meetup;
  final Function(String) onCancelMeetup;
  final VoidCallback onReturnToSwiping;

  const MeetupView({
    super.key,
    required this.meetup,
    required this.onCancelMeetup,
    required this.onReturnToSwiping,
  });

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
    final l10n = AppLocalizations.of(context)!;

    // Parse the meetup time from UTC
    final DateTime utcMeetupTime = DateTime.parse(match['meetup_time']);

    // Convert UTC time to local time
    final DateTime localMeetupTime = utcMeetupTime.toLocal();

    // Format the time as HH:MM
    final String formattedTime =
        '${localMeetupTime.hour.toString().padLeft(2, '0')}:${localMeetupTime.minute.toString().padLeft(2, '0')}';

    // Format the date using the current locale
    final String formattedDate = _formatLocalizedDate(localMeetupTime, context);

    // Check if the meetup has passed (more than 1 hour after the meetup time)
    final bool meetupPassed = DateTime.now().isAfter(
      localMeetupTime.add(const Duration(hours: 1)),
    );

    // Get screen height to calculate top third
    final screenHeight = MediaQuery.of(context).size.height;
    final topThirdHeight = screenHeight / 3.0;

    // Define gradient colors for consistency
    final gradientColors = [Colors.purple.shade300, Colors.blue.shade300];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add more top padding to push content lower
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),

          // Header text with gradient username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Text(
                  meetupPassed ? l10n.recentlyMet : l10n.aboutToMeet,
                  style: AppTheme.headingStyle.copyWith(
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                ),
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                  child: Text(
                    otherUser['name'] ?? l10n.someone,
                    style: AppTheme.headingStyle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // This color is used as the mask
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Profile pictures section with adjusted height
          SizedBox(
            height: topThirdHeight * 1.0, // Increased height
            child: Stack(
              clipBehavior: Clip.none, // Allow children to overflow
              children: [
                // Current user profile picture with animation
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.1,
                  top: topThirdHeight * 0.2, // Adjusted position
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
                          height: 135,
                          width: 135,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: CircleAvatar(
                              radius: 63.5,
                              backgroundImage:
                                  currentUser['profile_picture_url'] != null
                                      ? NetworkImage(
                                        currentUser['profile_picture_url'],
                                      )
                                      : null,
                              child:
                                  currentUser['profile_picture_url'] == null
                                      ? const Icon(Icons.person, size: 58)
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
                  right: MediaQuery.of(context).size.width * 0.1,
                  top: topThirdHeight * 0.35, // Adjusted position
                  child: AnimatedBuilder(
                    animation: _otherUserAnimController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _otherUserOffsetX * _otherUserAnimController.value,
                          _otherUserOffsetY * _otherUserAnimController.value,
                        ),
                        child: Container(
                          height: 180,
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
                            padding: const EdgeInsets.all(4.0),
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
                                      ? const Icon(Icons.person, size: 78)
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

          // Spacer with flex to push the card to the bottom
          const Spacer(flex: 1),

          // Meetup details card - positioned at the bottom with enough space
          Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white, // Set the card's background color to white
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
                              final Uri url = Uri.parse(
                                place['google_maps_uri'],
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              } else {}
                            },
                            icon: const Icon(Icons.map),
                            label: Text(l10n.showOnMap),
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
                      icon: const Icon(
                        Icons.cancel,
                        color: AppTheme.accentColor,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text(l10n.cancelMeetup),
                                content: Text(l10n.cancelMeetupConfirm),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: Text(l10n.no),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onCancelMeetup(match['id']);
                                    },
                                    child: Text(l10n.yes),
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
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: widget.onReturnToSwiping,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.returnToSwiping),
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

  // Helper method to format date according to locale
  String _formatLocalizedDate(DateTime date, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    if (locale == 'fr') {
      // French format: "jeudi 6 mai" or "jeudi 1er mai" (day month, no comma, proper capitalization)
      final dayName = DateFormat('EEEE', 'fr').format(date);
      final monthName = DateFormat('MMMM', 'fr').format(date);
      final day = date.day;

      // Capitalize first letter of day and month
      final capitalizedDay = dayName[0].toUpperCase() + dayName.substring(1);
      final capitalizedMonth =
          monthName[0].toUpperCase() + monthName.substring(1);

      // Add ordinal suffix for French (1er for 1st, nothing for others)
      final dayWithSuffix = day == 1 ? '1er' : day.toString();

      return '$capitalizedDay $dayWithSuffix $capitalizedMonth';
    } else {
      // English format: "Thursday, May 6th"
      return DateFormat('EEEE, MMMM d', 'en').format(date) +
          _getDaySuffix(date.day);
    }
  }

  // Helper method to get the day suffix (th, st, nd, rd for English; er, e for French)
  String _getDaySuffix(int day) {
    final locale = Localizations.localeOf(context).languageCode;

    if (locale == 'fr') {
      // French ordinal suffixes
      if (day == 1) {
        return 'er';
      } else {
        return '';
      }
    } else {
      // English ordinal suffixes
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
}
