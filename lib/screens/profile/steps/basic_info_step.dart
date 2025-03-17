import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_theme.dart';
import '../../../services/profile_completion_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../l10n/app_localizations.dart';

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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSelectValue),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedInterestedIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSelectValue),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tellUsAboutYourself,
              style: AppTheme.headingStyle,
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              l10n.basicInfoDescription,
              style: AppTheme.smallTextStyle,
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 32),

            // Age Field
            CustomTextField(
              label: l10n.ageLabel,
              hint: l10n.enterAge,
              controller: _ageController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.cake_outlined),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.errorFieldRequired(l10n.ageLabel);
                }
                final age = int.tryParse(value);
                if (age == null || age < 18) {
                  return l10n.errorAgeRange;
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
                  l10n.genderLabel,
                  hint: l10n.selectGender,
                ).copyWith(prefixIcon: const Icon(Icons.person_outline)),
                value: _selectedGender,
                items:
                    _genderOptions.map((gender) {
                      String translatedGender;
                      switch (gender) {
                        case 'Male':
                          translatedGender = l10n.genderMale;
                          break;
                        case 'Female':
                          translatedGender = l10n.genderFemale;
                          break;
                        default:
                          translatedGender = l10n.genderOther;
                      }
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(translatedGender),
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
                  l10n.interestedInLabel,
                  hint: l10n.selectPreference,
                ).copyWith(prefixIcon: const Icon(Icons.favorite_outline)),
                value: _selectedInterestedIn,
                items:
                    _interestedInOptions.map((option) {
                      String translatedOption;
                      switch (option) {
                        case 'Male':
                          translatedOption = l10n.interestedInMale;
                          break;
                        case 'Female':
                          translatedOption = l10n.interestedInFemale;
                          break;
                        default:
                          translatedOption = l10n.interestedInEveryone;
                      }
                      return DropdownMenuItem(
                        value: option,
                        child: Text(translatedOption),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: CustomButton(
                text: l10n.next,
                onPressed: _submitBasicInfo,
                icon: Icons.arrow_forward,
              ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }
}
