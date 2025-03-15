import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../constants/app_theme.dart';
import '../../../services/profile_completion_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/error_message_widget.dart';
import '../../../utils/network_error_handler.dart';
import '../../../services/connectivity_service.dart';

class VoiceBioStep extends StatefulWidget {
  const VoiceBioStep({super.key});

  @override
  State<VoiceBioStep> createState() => _VoiceBioStepState();
}

class _VoiceBioStepState extends State<VoiceBioStep> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  File? _audioFile;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;

  int _recordingDuration = 0;
  Timer? _recordingTimer;
  StreamSubscription? _playerSubscription;
  int _rebuildCounter = 0; // Used to force UI rebuilds

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if available
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    if (profileService.voiceBio != null) {
      _audioFile = profileService.voiceBio;
    }

    // Set up audio player listeners
    _setupAudioPlayerListeners();
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
            _isPlaying = false;
            _rebuildCounter++; // Force UI rebuild
            print("Audio playback completed, isPlaying set to false");
          });
        } else if (state.playing && !_isPlaying) {
          // Ensure UI reflects playing state if somehow out of sync
          setState(() {
            _isPlaying = true;
            _rebuildCounter++; // Force UI rebuild
            print("Audio is playing, isPlaying set to true");
          });
        } else if (!state.playing &&
            _isPlaying &&
            state.processingState != ProcessingState.loading &&
            state.processingState != ProcessingState.buffering) {
          // Handle case where player stopped but UI still shows playing
          setState(() {
            _isPlaying = false;
            _rebuildCounter++; // Force UI rebuild
            print("Audio stopped playing, isPlaying set to false");
          });
        }
      }
    });

    // Also listen for errors
    _audioPlayer.playbackEventStream.listen(
      (event) {
        // Handle playback events if needed
        print('Audio playback event: $event');
      },
      onError: (Object e, StackTrace st) {
        print('Audio player error: $e');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _errorMessage = 'Error playing audio: ${e.toString()}';
            _rebuildCounter++; // Force UI rebuild
          });
        }
      },
    );
  }

  @override
  void dispose() {
    // Stop any ongoing recording or playback
    if (_isRecording) {
      _stopRecording();
    }

    if (_isPlaying) {
      _audioPlayer.stop();
    }

    // Cancel timers and subscriptions
    _recordingTimer?.cancel();
    _playerSubscription?.cancel();

    // Dispose of audio resources
    _audioRecorder.dispose();
    _audioPlayer.dispose();

    print("Voice bio step disposed, all audio resources cleaned up");
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Stop any playing audio first
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      }

      // Request microphone permission
      final hasPermission = await _audioRecorder.hasPermission();
      if (hasPermission) {
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/voice_bio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Configure recording
        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        // Start recording
        await _audioRecorder.start(config, path: filePath);

        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _errorMessage = null;
          _audioFile = null; // Clear previous recording
        });

        // Start timer to track recording duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });

          // Automatically stop recording after 10 seconds
          if (_recordingDuration >= 10) {
            _stopRecording();
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Microphone permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: ${e.toString()}';
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        if (_recordingDuration < 5) {
          setState(() {
            _errorMessage = 'Recording must be at least 5 seconds long';
            _audioFile = null;
          });
          return;
        }

        setState(() {
          _audioFile = File(path);
          if (_recordingDuration > 10) {
            _errorMessage = 'Recording was cut to 10 seconds';
          } else {
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = 'Failed to stop recording: ${e.toString()}';
      });
    }
  }

  Future<void> _playRecording() async {
    if (_audioFile == null) return;

    try {
      if (_isPlaying) {
        // Stop playback if already playing
        print("Attempting to stop audio playback");

        // First update UI to provide immediate feedback
        setState(() {
          _isPlaying = false;
          _rebuildCounter++; // Force UI rebuild
          print("UI updated to show stopped state");
        });

        // Then stop the player
        await _audioPlayer.stop();
        print("Audio player stopped");

        return;
      }

      // Reset player and set new file
      await _audioPlayer.stop();

      // Set up listeners before playing
      _setupAudioPlayerListeners();

      // Update UI before playing to ensure immediate feedback
      setState(() {
        _isPlaying = true;
        _rebuildCounter++; // Force UI rebuild
        print("Starting audio playback, isPlaying set to true");
      });

      // Set file and play
      await _audioPlayer.setFilePath(_audioFile!.path);

      // Start playback
      await _audioPlayer.play();
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _errorMessage = 'Failed to play recording: ${e.toString()}';
        print("Error playing audio: ${e.toString()}");
      });
    }
  }

  void _confirmVoiceBio() {
    if (_audioFile == null) {
      setState(() {
        _errorMessage = 'Please record a voice bio';
      });
      return;
    }

    if (_recordingDuration < 5) {
      setState(() {
        _errorMessage = 'Recording must be at least 5 seconds long';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Save voice bio and complete profile
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    profileService.setVoiceBio(_audioFile!);

    // First check for internet connection
    ConnectivityService.isConnected().then((hasConnection) async {
      if (!hasConnection) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(
              SocketException('No internet connection'),
            );
          });
        }
        return;
      }

      // Complete profile if we have connection
      try {
        final success = await profileService.completeProfile();
        if (!success && mounted) {
          setState(() {
            _isLoading = false;
            // Get the error message from the service
            _errorMessage = profileService.errorMessage;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(error);
          });
        }
      }
    });
  }

  String get _formattedDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Check if the error is a network error
    final bool isNetworkError =
        _errorMessage != null &&
        (_errorMessage!.contains('internet') ||
            _errorMessage!.contains('connection'));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record your voice bio',
            style: AppTheme.headingStyle,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            'Tell others about yourself in 5-10 seconds',
            style: AppTheme.smallTextStyle,
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
          const SizedBox(height: 32),

          // Error message
          if (_errorMessage != null)
            isNetworkError
                ? ErrorMessageWidget(
                  message: _errorMessage!,
                  onRetry: _confirmVoiceBio,
                  isNetworkError: true,
                )
                : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTheme.smallTextStyle.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().shake(),

          if (_errorMessage != null) const SizedBox(height: 24),

          // Recording visualization
          Expanded(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color:
                      _isRecording
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : (_isPlaying
                              ? AppTheme.primaryColor.withOpacity(0.05)
                              : Colors.grey.shade200),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecording
                          ? Icons.mic
                          : (_isPlaying
                              ? Icons.volume_up
                              : (_audioFile != null
                                  ? Icons.mic_none
                                  : Icons.mic_off)),
                      size: 80,
                      color:
                          _isRecording || _isPlaying
                              ? AppTheme.primaryColor
                              : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? _formattedDuration
                          : (_isPlaying
                              ? 'Playing...'
                              : (_audioFile != null
                                  ? 'Recording saved'
                                  : 'No recording')),
                      key: ValueKey('audio_status_$_rebuildCounter'),
                      style: AppTheme.bodyStyle.copyWith(
                        color:
                            _isRecording || _isPlaying
                                ? AppTheme.primaryColor
                                : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
            ),
          ),

          // Recording controls
          if (_isRecording)
            // Only show stop button when recording
            CustomButton(
              text: 'Stop Recording',
              onPressed: _stopRecording,
              icon: Icons.stop,
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms)
          else if (_audioFile != null && _recordingDuration >= 5)
            // Show controls when recording is valid
            Column(
              key: ValueKey(
                'audio_controls_${_rebuildCounter}_${_isPlaying ? 'playing' : 'stopped'}',
              ),
              children: [
                // Play/Stop button
                CustomButton(
                  text: _isPlaying ? 'Stop Playing' : 'Play Recording',
                  onPressed: _playRecording,
                  icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                  isOutlined: true,
                ),
                const SizedBox(height: 16),

                // Record Again button
                CustomButton(
                  text: 'Record Again',
                  onPressed: _isPlaying ? () {} : _startRecording,
                  icon: Icons.mic,
                  isOutlined: true,
                  isDisabled: _isPlaying,
                ),
                const SizedBox(height: 16),

                // Finish button
                CustomButton(
                  text: 'Finish',
                  onPressed: _isPlaying ? () {} : _confirmVoiceBio,
                  isLoading: _isLoading,
                  icon: Icons.check,
                  isDisabled: _isPlaying,
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms)
          else
            // Show record button when no recording or invalid recording
            CustomButton(
              text: 'Record Voice Bio',
              onPressed: _startRecording,
              icon: Icons.mic,
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
        ],
      ),
    );
  }
}
