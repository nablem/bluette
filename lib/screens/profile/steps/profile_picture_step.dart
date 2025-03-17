import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_theme.dart';
import '../../../services/profile_completion_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../l10n/app_localizations.dart';

class ProfilePictureStep extends StatefulWidget {
  const ProfilePictureStep({super.key});

  @override
  State<ProfilePictureStep> createState() => _ProfilePictureStepState();
}

class _ProfilePictureStepState extends State<ProfilePictureStep> {
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if available
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    if (profileService.profilePicture != null) {
      _imageFile = profileService.profilePicture;
    }
  }

  Future<void> _takePicture() async {
    setState(() {
      _isLoading = true;
    });

    // Capture ScaffoldMessenger before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.errorUpdateProfilePicture(e.toString()),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _confirmPicture() {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.errorFieldRequired(AppLocalizations.of(context)!.profilePicture),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Save profile picture
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    profileService.setProfilePicture(_imageFile!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addProfilePicture,
            style: AppTheme.headingStyle,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            l10n.profilePictureDescription,
            style: AppTheme.smallTextStyle,
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
          const SizedBox(height: 32),

          // Profile Picture Preview
          Expanded(
            child: Center(
              child:
                  _imageFile == null
                      ? Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 120,
                          color: Colors.grey,
                        ),
                      ).animate().fadeIn(delay: 400.ms, duration: 600.ms)
                      : Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms),
            ),
          ),

          // Camera Button
          CustomButton(
            text: _imageFile == null ? l10n.takePicture : l10n.retakePicture,
            onPressed: _takePicture,
            isLoading: _isLoading,
            icon: Icons.camera_alt,
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

          const SizedBox(height: 16),

          // Next Button
          if (_imageFile != null)
            CustomButton(
              text: l10n.next,
              onPressed: _confirmPicture,
              icon: Icons.arrow_forward,
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
        ],
      ),
    );
  }
}
