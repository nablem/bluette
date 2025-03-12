import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_theme.dart';
import '../../../services/profile_completion_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedInterestedIn;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _interestedInOptions = ['Male', 'Female', 'Everyone'];

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if available
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    _selectedGender = profileService.gender;
    _selectedInterestedIn = profileService.interestedIn;
    if (profileService.age != null) {
      _ageController.text = profileService.age.toString();
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _submitBasicInfo() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedInterestedIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who you are interested in'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Save basic info
    final profileService = Provider.of<ProfileCompletionService>(
      context,
      listen: false,
    );
    profileService.setBasicInfo(
      name: '', // Empty name, will use the one from signup
      gender: _selectedGender!,
      interestedIn: _selectedInterestedIn!,
      age: int.parse(_ageController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us about yourself',
              style: AppTheme.headingStyle,
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'This information helps us find better matches for you',
              style: AppTheme.smallTextStyle,
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 32),

            // Age Field
            CustomTextField(
              label: 'Age',
              hint: 'Enter your age',
              controller: _ageController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.cake_outlined),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your age';
                }
                final age = int.tryParse(value);
                if (age == null || age < 18) {
                  return 'You must be at least 18 years old';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

            // Gender Dropdown
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonFormField<String>(
                decoration: AppTheme.inputDecoration(
                  'Gender',
                  hint: 'Select your gender',
                ).copyWith(prefixIcon: const Icon(Icons.person_outline)),
                value: _selectedGender,
                items:
                    _genderOptions.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                style: AppTheme.bodyStyle,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            // Interested In Dropdown
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonFormField<String>(
                decoration: AppTheme.inputDecoration(
                  'Interested In',
                  hint: 'Select who you are interested in',
                ).copyWith(prefixIcon: const Icon(Icons.favorite_outline)),
                value: _selectedInterestedIn,
                items:
                    _interestedInOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInterestedIn = value;
                  });
                },
                style: AppTheme.bodyStyle,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

            const Spacer(),

            // Next Button
            CustomButton(
              text: 'Next',
              onPressed: _submitBasicInfo,
              icon: Icons.arrow_forward,
            ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
