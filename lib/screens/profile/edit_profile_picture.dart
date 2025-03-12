import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_theme.dart';
import '../../widgets/custom_button.dart';

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
      setState(() {
        _errorMessage = 'Failed to take picture: ${e.toString()}';
      });
    }
  }

  void _confirmImage() {
    if (_imageFile == null) {
      setState(() {
        _errorMessage = 'Please take a picture';
      });
      return;
    }

    Navigator.of(context).pop(_imageFile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile Picture'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Update your profile picture', style: AppTheme.headingStyle),
            const SizedBox(height: 8),
            Text(
              'Take a clear photo of your face to help others recognize you',
              style: AppTheme.smallTextStyle,
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
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
              text: _imageFile == null ? 'Take Picture' : 'Retake Picture',
              onPressed: _takePicture,
              icon: Icons.camera_alt,
              isOutlined: true,
            ),

            const SizedBox(height: 24),

            // Confirm button
            CustomButton(
              text: 'Confirm',
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
