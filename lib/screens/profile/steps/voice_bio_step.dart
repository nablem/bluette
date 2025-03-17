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
import '../../../l10n/app_localizations.dart';

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
        if (state.processingState == ProcessingState.completed) {
          // When playback completes, update UI
          setState(() {
            _isPlaying = false;
            _rebuildCounter++; // Force UI rebuild
          });
        } else if (state.playing && !_isPlaying) {
          // Ensure UI reflects playing state if somehow out of sync
          setState(() {
            _isPlaying = true;
            _rebuildCounter++; // Force UI rebuild
          });
        } else if (!state.playing &&
            _isPlaying &&
            state.processingState != ProcessingState.loading &&
            state.processingState != ProcessingState.buffering) {
          // Handle case where player stopped but UI still shows playing
          setState(() {
            _isPlaying = false;
            _rebuildCounter++; // Force UI rebuild
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
            _isPlaying = false;
            _errorMessage = AppLocalizations.of(
              context,
            )!.errorPlayVoiceBio(e.toString());
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
          _errorMessage =
              AppLocalizations.of(context)!.errorMicrophonePermission;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.errorStartRecording(e.toString());
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
            _errorMessage =
                AppLocalizations.of(context)!.errorRecordingDuration;
            _audioFile = null;
          });
          return;
        }

        setState(() {
          _audioFile = File(path);
          if (_recordingDuration > 10) {
            _errorMessage = AppLocalizations.of(context)!.errorRecordingTooLong;
          } else {
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = AppLocalizations.of(
          context,
        )!.errorStopRecording(e.toString());
      });
    }
  }

  Future<void> _playRecording() async {
    if (_audioFile == null) return;

    try {
      if (_isPlaying) {
        // Stop playback if already playing
        setState(() {
          _isPlaying = false;
          _rebuildCounter++; // Force UI rebuild
        });

        // Then stop the player
        await _audioPlayer.stop();
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
      });

      // Set file and play
      await _audioPlayer.setFilePath(_audioFile!.path);

      // Start playback
      await _audioPlayer.play();
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _errorMessage = AppLocalizations.of(
          context,
        )!.errorPlayVoiceBio(e.toString());
      });
    }
  }

  void _confirmVoiceBio() {
    if (_audioFile == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorNoVoiceBio;
      });
      return;
    }

    if (_recordingDuration < 5) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorRecordingDuration;
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
    final l10n = AppLocalizations.of(context)!;
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
            l10n.recordVoiceBio,
            style: AppTheme.headingStyle,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            l10n.voiceBioDescription,
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
                    color: AppTheme.errorColor.withAlpha(26),
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
                          ? AppTheme.primaryColor.withAlpha(26)
                          : (_isPlaying
                              ? AppTheme.primaryColor.withAlpha(13)
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
                              ? l10n.playingVoiceBio
                              : (_audioFile != null
                                  ? l10n.recordingSaved
                                  : l10n.noVoiceBio)),
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

          const SizedBox(height: 32),

          // Recording controls
          if (_isRecording)
            // Only show stop button when recording
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: CustomButton(
                text: l10n.stopRecording,
                onPressed: _stopRecording,
                icon: Icons.stop,
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            )
          else if (_audioFile != null && _recordingDuration >= 5)
            // Show controls when recording is valid
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                key: ValueKey(
                  'audio_controls_${_rebuildCounter}_${_isPlaying ? 'playing' : 'stopped'}',
                ),
                children: [
                  // Play/Stop button
                  CustomButton(
                    text: _isPlaying ? l10n.stopPlaying : l10n.playVoiceBio,
                    onPressed: _playRecording,
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    isOutlined: true,
                  ),
                  const SizedBox(height: 16),

                  // Record Again button
                  CustomButton(
                    text: l10n.recordAgain,
                    onPressed: _isPlaying ? () {} : _startRecording,
                    icon: Icons.mic,
                    isOutlined: true,
                    isDisabled: _isPlaying,
                  ),
                  const SizedBox(height: 16),

                  // Finish button
                  CustomButton(
                    text: l10n.finish,
                    onPressed: _isPlaying ? () {} : _confirmVoiceBio,
                    isLoading: _isLoading,
                    icon: Icons.check,
                    isDisabled: _isPlaying,
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            )
          else
            // Show record button when no recording or invalid recording
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: CustomButton(
                text: l10n.recordVoiceBio,
                onPressed: _startRecording,
                icon: Icons.mic,
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            ),
        ],
      ),
    );
  }
}
