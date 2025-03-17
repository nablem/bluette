import 'dart:io';
import 'package:flutter/material.dart';
import 'supabase_service.dart';

enum ProfileCompletionStep { basicInfo, profilePicture, voiceBio, completed }

class ProfileCompletionService extends ChangeNotifier {
  ProfileCompletionStep _currentStep = ProfileCompletionStep.basicInfo;
  String _name = '';
  String? _gender;
  String? _interestedIn;
  int? _age;
  File? _profilePicture;
  File? _voiceBio;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  ProfileCompletionStep get currentStep => _currentStep;
  String get name => _name;
  String? get gender => _gender;
  String? get interestedIn => _interestedIn;
  int? get age => _age;
  File? get profilePicture => _profilePicture;
  File? get voiceBio => _voiceBio;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isCompleted => _currentStep == ProfileCompletionStep.completed;

  // Step 1: Basic Info
  void setBasicInfo({
    required String name,
    required String gender,
    required String interestedIn,
    required int age,
  }) {
    _name = name;
    _gender = gender;
    _interestedIn = interestedIn;
    _age = age;
    _currentStep = ProfileCompletionStep.profilePicture;
    notifyListeners();
  }

  // Step 2: Profile Picture
  void setProfilePicture(File picture) {
    _profilePicture = picture;
    _currentStep = ProfileCompletionStep.voiceBio;
    notifyListeners();
  }

  // Step 3: Voice Bio
  void setVoiceBio(File audio) {
    _voiceBio = audio;
    notifyListeners();
  }

  // Complete profile
  Future<bool> completeProfile() async {
    if (_gender == null ||
        _interestedIn == null ||
        _age == null ||
        _profilePicture == null ||
        _voiceBio == null) {
      _errorMessage = 'Please complete all steps before proceeding';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current user data
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Ensure we have a valid email
      String email;
      if (currentUser.email != null && currentUser.email!.isNotEmpty) {
        email = currentUser.email!;
      } else {
        // Fallback email if somehow the user has no email
        email = 'user_${DateTime.now().millisecondsSinceEpoch}@example.com';
      }

      // Calculate default filter values based on user's age
      final int userAge = _age!;
      final int minAge = (userAge - 5) < 18 ? 18 : (userAge - 5);
      final int maxAge = userAge + 5;

      // Update basic info with explicit email and default filter values
      final Map<String, dynamic> userData = {
        'id': currentUser.id,
        'email': email,
        'name':
            _name.isNotEmpty
                ? _name
                : (currentUser.userMetadata?['name'] ?? email.split('@')[0]),
        'gender': _gender,
        'interested_in': _interestedIn,
        'age': _age,
        'min_age': minAge,
        'max_age': maxAge,
      };

      

      // Update the profile with basic info first
      await SupabaseService.updateUserData(userData);

      // Upload profile picture
      final pictureUrl = await SupabaseService.uploadProfilePicture(
        _profilePicture!,
      );
      if (pictureUrl == null) {
        throw Exception('Failed to upload profile picture');
      }

      // Upload voice bio
      final voiceBioUrl = await SupabaseService.uploadVoiceBio(_voiceBio!);
      if (voiceBioUrl == null) {
        throw Exception('Failed to upload voice bio');
      }

      _currentStep = ProfileCompletionStep.completed;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      
      return false;
    }
  }

  // Reset error message
  void resetError() {
    _errorMessage = null;
    notifyListeners();
  }
}
