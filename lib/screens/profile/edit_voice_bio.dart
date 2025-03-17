import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';

class EditVoiceBio extends StatefulWidget {
  const EditVoiceBio({super.key});

  @override
  State<EditVoiceBio> createState() => _EditVoiceBioState();
}

class _EditVoiceBioState extends State<EditVoiceBio> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  File? _audioFile;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _errorMessage;

  int _recordingDuration = 0;
  Timer? _recordingTimer;
  StreamSubscription? _playerSubscription;
  int _rebuildCounter = 0; // Used to force UI rebuilds

  @override
  void initState() {
    super.initState();
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
        }
      }
    });
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
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _errorMessage = l10n.errorUpdateVoiceBio(
            'Microphone permission denied',
          );
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorUpdateVoiceBio(e.toString());
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
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            _errorMessage = l10n.errorRecordingDuration;
            _audioFile = null;
          });
          return;
        }

        setState(() {
          _audioFile = File(path);
          if (_recordingDuration > 10) {
            final l10n = AppLocalizations.of(context)!;
            _errorMessage = l10n.errorUpdateVoiceBio(
              'Recording was cut to 10 seconds',
            );
          } else {
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isRecording = false;
        _errorMessage = l10n.errorUpdateVoiceBio(e.toString());
      });
    }
  }

  Future<void> _playRecording() async {
    if (_audioFile == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _rebuildCounter++; // Force UI rebuild
        });
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
      await _audioPlayer.play();
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isPlaying = false;
        _errorMessage = l10n.errorPlayVoiceBio(e.toString());
      });
    }
  }

  void _confirmVoiceBio() {
    if (_audioFile == null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorUpdateVoiceBio('Please record a voice bio');
      });
      return;
    }

    if (_recordingDuration < 5) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorRecordingDuration;
      });
      return;
    }

    Navigator.of(context).pop(_audioFile);
  }

  String get _formattedDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.editProfile,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.voiceBioLabel, style: AppTheme.headingStyle),
            const SizedBox(height: 8),
            Text(l10n.voiceBioDescription, style: AppTheme.smallTextStyle),
            const SizedBox(height: 32),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor),
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
              ),

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
                                    ? 'Recording saved'
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
                ),
              ),
            ),

            // Recording controls
            if (_isRecording)
              // Only show stop button when recording
              CustomButton(
                text: l10n.stopRecording,
                onPressed: _stopRecording,
                icon: Icons.stop,
              )
            else if (_audioFile != null && _recordingDuration >= 5)
              // Show controls when recording is valid
              Column(
                key: ValueKey(
                  'controls_$_rebuildCounter',
                ), // Force rebuild when state changes
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
                    text: l10n.save,
                    onPressed: _isPlaying ? () {} : _confirmVoiceBio,
                    icon: Icons.check,
                    isDisabled: _isPlaying,
                  ),
                ],
              )
            else
              // Show record button when no recording or invalid recording
              CustomButton(
                text: l10n.recordVoiceBio,
                onPressed: _startRecording,
                icon: Icons.mic,
              ),
          ],
        ),
      ),
    );
  }
}
