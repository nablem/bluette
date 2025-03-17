import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';

class EditProfilePicture extends StatefulWidget {
  const EditProfilePicture({super.key});

  @override
  State<EditProfilePicture> createState() => _EditProfilePictureState();
}

class _EditProfilePictureState extends State<EditProfilePicture> {
  File? _imageFile;
  final _imagePicker = ImagePicker();
  String? _errorMessage;

  Future<void> _takePicture() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorUpdateProfilePicture(e.toString());
      });
    }
  }

  void _confirmImage() {
    if (_imageFile == null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorUpdateProfilePicture('Please take a picture');
      });
      return;
    }

    Navigator.of(context).pop(_imageFile);
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
            Text('Photo', style: AppTheme.headingStyle),
            const SizedBox(height: 8),
            Text(
              l10n.profilePictureDescription,
              style: AppTheme.smallTextStyle,
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
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

            // Image preview
            Expanded(
              child: Center(
                child:
                    _imageFile != null
                        ? Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 3,
                            ),
                            image: DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        : Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 32),

            // Camera button
            CustomButton(
              text: _imageFile == null ? l10n.takePicture : l10n.retakePicture,
              onPressed: _takePicture,
              icon: Icons.camera_alt,
              isOutlined: true,
            ),

            const SizedBox(height: 24),

            // Confirm button
            CustomButton(
              text: l10n.save,
              onPressed: _confirmImage,
              icon: Icons.check,
              isDisabled: _imageFile == null,
            ),
          ],
        ),
      ),
    );
  }
}
