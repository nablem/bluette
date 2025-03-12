import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/app_theme.dart';
import 'dart:math' as math;

class ProfileCard extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileCard({super.key, required this.profile});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // Set up listeners for player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;

          // When playback completes, reset position and show play button
          if (state.processingState == ProcessingState.completed) {
            _position = Duration.zero;
            _isPlaying = false;
          }
        });
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Pre-load the audio if available
    final voiceBioUrl = widget.profile['voice_bio_url'];
    if (voiceBioUrl != null && voiceBioUrl.isNotEmpty) {
      _loadAudio(voiceBioUrl);
    }
  }

  Future<void> _loadAudio(String url) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _audioPlayer.setUrl(url);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playAudio() async {
    if (!_isInitialized) {
      final voiceBioUrl = widget.profile['voice_bio_url'];
      if (voiceBioUrl != null && voiceBioUrl.isNotEmpty) {
        await _loadAudio(voiceBioUrl);
      } else {
        return;
      }
    }

    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isLoading = true;
    });

    if (_isPlaying) {
      _pauseAudio();
    } else {
      _playAudio();
    }

    // Set loading to false after a short delay to ensure UI updates
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.profile['name'] ?? 'No Name';
    final String? profilePictureUrl = widget.profile['profile_picture_url'];
    final String? voiceBioUrl = widget.profile['voice_bio_url'];
    final bool hasVoiceBio = voiceBioUrl != null && voiceBioUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // Profile Picture
              Positioned.fill(
                child:
                    profilePictureUrl != null && profilePictureUrl.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: profilePictureUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
              ),

              // Gradient overlay at the bottom for better text visibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: hasVoiceBio ? 180 : 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Name and Audio Player
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Audio Player
                    if (hasVoiceBio) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            // Play/Pause Button
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Icon(
                                            _isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                ),
                              ),
                            ),

                            // Progress Bar
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Progress Slider
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 14,
                                            ),
                                        activeTrackColor: AppTheme.primaryColor,
                                        inactiveTrackColor: Colors.white
                                            .withOpacity(0.3),
                                        thumbColor: Colors.white,
                                        overlayColor: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                      ),
                                      child: Slider(
                                        value:
                                            _position.inMilliseconds
                                                        .toDouble() >
                                                    _duration.inMilliseconds
                                                        .toDouble()
                                                ? _duration.inMilliseconds
                                                    .toDouble()
                                                : _position.inMilliseconds
                                                    .toDouble(),
                                        min: 0,
                                        max:
                                            _duration.inMilliseconds
                                                        .toDouble() ==
                                                    0
                                                ? 1
                                                : _duration.inMilliseconds
                                                    .toDouble(),
                                        onChanged: (value) {
                                          if (_isInitialized) {
                                            final position = Duration(
                                              milliseconds: value.toInt(),
                                            );
                                            _audioPlayer.seek(position);

                                            // If audio was paused and user seeks, we should start playing
                                            if (!_isPlaying) {
                                              _playAudio();
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Duration
                            Text(
                              _formatDuration(_duration - _position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
