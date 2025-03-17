import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';
import '../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Add a small delay for the splash screen to be visible
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      if (SupabaseService.isLoggedIn) {
        // Check if user has completed their profile
        final userProfile = await SupabaseService.getUserProfile();

        if (userProfile == null ||
            userProfile['profile_picture_url'] == null ||
            userProfile['voice_bio_url'] == null) {
          // Profile is incomplete, navigate to profile completion
          Navigator.pushReplacementNamed(context, '/profile_completion');
        } else {
          // Profile is complete, navigate to home
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset('assets/icon/icon-petrol-mini.png'),
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 24),

            // App Name
            Text(
              'Bluette',
              style: AppTheme.headingStyle.copyWith(
                fontSize: 36,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 800.ms),

            const SizedBox(height: 12),

            // Tagline
            Text(
              'Que des étincelles',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 800.ms),

            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ).animate().fadeIn(delay: 1200.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
