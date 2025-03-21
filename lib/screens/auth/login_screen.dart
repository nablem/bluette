import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'signup_screen.dart';
import '../../utils/network_error_handler.dart';
import '../../widgets/error_message_widget.dart';
import '../../services/connectivity_service.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check for internet connection first
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        throw SocketException('No internet connection');
      }

      final response = await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (response.user != null) {
          // Check if profile is complete
          final profile = await SupabaseService.getUserProfile();
          if (profile == null ||
              profile['name'] == null ||
              profile['gender'] == null ||
              profile['interested_in'] == null ||
              profile['age'] == null ||
              profile['profile_picture_url'] == null ||
              profile['voice_bio_url'] == null) {
            // Profile is incomplete, go to profile completion
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/profile_completion');
            }
          } else {
            // Profile is complete, go to home
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          }
        } else {
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = NetworkErrorHandler.getUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  void _resetPassword() {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterEmailFirst),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    SupabaseService.resetPassword(_emailController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.passwordResetSent),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // App Logo and Name
                  Center(
                    child: Column(
                      children: [
                        Container(
                              width: 80,
                              height: 80,
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
                                padding: const EdgeInsets.all(15.0),
                                child: Image.asset(
                                  'assets/icon/icon-petrol-mini.png',
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(
                              begin: -0.2,
                              end: 0,
                              curve: Curves.easeOutQuad,
                              duration: 600.ms,
                            ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.appTitle,
                          style: AppTheme.headingStyle.copyWith(
                            fontSize: 32,
                            color: AppTheme.primaryColor,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                        const SizedBox(height: 8),
                        Text(
                          l10n.findPerfectMatch,
                          style: AppTheme.smallTextStyle,
                        ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Welcome Text
                  Text(
                    l10n.welcomeBack,
                    style: AppTheme.headingStyle,
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInToContinue,
                    style: AppTheme.smallTextStyle,
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
                  const SizedBox(height: 32),

                  // Error Message
                  if (_errorMessage != null)
                    ErrorMessageWidget(
                      message: _errorMessage!,
                      onRetry:
                          _errorMessage!.contains('internet') ||
                                  _errorMessage!.contains('connection')
                              ? _login
                              : null,
                      isNetworkError:
                          _errorMessage!.contains('internet') ||
                          _errorMessage!.contains('connection'),
                    ),

                  if (_errorMessage != null) const SizedBox(height: 24),

                  // Email Field
                  CustomTextField(
                    label: l10n.emailLabel,
                    hint: l10n.emailLabel,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.errorInvalidEmail;
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return l10n.errorInvalidEmail;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),

                  // Password Field
                  PasswordTextField(
                    label: l10n.passwordLabel,
                    hint: l10n.passwordLabel,
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.errorInvalidPassword;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTheme.smallTextStyle.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1400.ms, duration: 600.ms),

                  const SizedBox(height: 24),

                  // Login Button
                  CustomButton(
                    text: l10n.loginButton,
                    onPressed: _login,
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 1600.ms, duration: 600.ms),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.dontHaveAccount,
                        style: AppTheme.smallTextStyle,
                      ),
                      TextButton(
                        onPressed: _navigateToSignup,
                        child: Text(
                          l10n.signupButton,
                          style: AppTheme.smallTextStyle.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1800.ms, duration: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
