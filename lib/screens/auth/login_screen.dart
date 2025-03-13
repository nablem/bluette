import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'signup_screen.dart';

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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
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
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid email or password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
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
    // Implement password reset functionality
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    SupabaseService.resetPassword(_emailController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset link sent to your email'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                    color: Colors.black.withOpacity(0.1),
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
                          'Bluette',
                          style: AppTheme.headingStyle.copyWith(
                            fontSize: 32,
                            color: AppTheme.primaryColor,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                        const SizedBox(height: 8),
                        Text(
                          'Find your perfect match',
                          style: AppTheme.smallTextStyle,
                        ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Welcome Text
                  Text(
                    'Welcome Back',
                    style: AppTheme.headingStyle,
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: AppTheme.smallTextStyle,
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
                  const SizedBox(height: 32),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
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
                              _errorMessage!,
                              style: AppTheme.smallTextStyle.copyWith(
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(delay: 100.ms),

                  if (_errorMessage != null) const SizedBox(height: 24),

                  // Email Field
                  CustomTextField(
                    label: 'Email',
                    hint: 'Enter your email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),

                  // Password Field
                  PasswordTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
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
                        'Forgot Password?',
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
                    text: 'Sign In',
                    onPressed: _login,
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 1600.ms, duration: 600.ms),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: AppTheme.smallTextStyle,
                      ),
                      TextButton(
                        onPressed: _navigateToSignup,
                        child: Text(
                          'Sign Up',
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
