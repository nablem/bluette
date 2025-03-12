import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/profile_completion_service.dart';
import 'steps/basic_info_step.dart';
import 'steps/profile_picture_step.dart';
import 'steps/voice_bio_step.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileCompletionService(),
      child: Consumer<ProfileCompletionService>(
        builder: (context, profileService, _) {
          // If profile is completed, navigate to home
          if (profileService.isCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/home');
            });
          }

          // Handle page changes based on current step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentStepIndex = profileService.currentStep.index;
            if (_pageController.hasClients &&
                _pageController.page?.round() != currentStepIndex) {
              _pageController.animateToPage(
                currentStepIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });

          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              title: Text(
                'Complete Your Profile',
                style: AppTheme.subheadingStyle,
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
            ),
            body: Column(
              children: [
                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStepIndicator(
                            1,
                            profileService.currentStep.index >= 0,
                            'Basic Info',
                          ),
                          _buildStepConnector(
                            profileService.currentStep.index >= 1,
                          ),
                          _buildStepIndicator(
                            2,
                            profileService.currentStep.index >= 1,
                            'Profile Picture',
                          ),
                          _buildStepConnector(
                            profileService.currentStep.index >= 2,
                          ),
                          _buildStepIndicator(
                            3,
                            profileService.currentStep.index >= 2,
                            'Voice Bio',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error message
                if (profileService.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.all(16),
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
                            profileService.errorMessage!,
                            style: AppTheme.smallTextStyle.copyWith(
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.errorColor,
                          ),
                          onPressed: () => profileService.resetError(),
                        ),
                      ],
                    ),
                  ).animate().shake(),

                // Step content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      BasicInfoStep(),
                      ProfilePictureStep(),
                      VoiceBioStep(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
            ),
            child: Center(
              child:
                  isActive
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                        step.toString(),
                        style: AppTheme.bodyStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.smallTextStyle.copyWith(
              color: isActive ? AppTheme.primaryColor : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
    );
  }
}
