import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        },
      );

      if (response.user != null) {
        // Create user profile
        await SupabaseService.updateUserData({
          'id': response.user!.id,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          // Navigate to profile completion screen
          Navigator.pushReplacementNamed(context, '/profile_completion');
        }
      } else {
        setState(() {
          _errorMessage = 'Please check your email to confirm your account';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign up. Email may already be in use.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Account Text
                  Text(
                    'Create Account',
                    style: AppTheme.headingStyle,
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to find your perfect match',
                    style: AppTheme.smallTextStyle,
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                  const SizedBox(height: 32),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withAlpha(26),
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

                  // Name Field
                  CustomTextField(
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    controller: _nameController,
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

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
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                  // Password Field
                  PasswordTextField(
                    label: 'Password',
                    hint: 'Create a password',
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

                  // Confirm Password Field
                  PasswordTextField(
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    controller: _confirmPasswordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signup(),
                  ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),

                  const SizedBox(height: 32),

                  // Terms and Conditions
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'By signing up, you agree to our Terms of Service and Privacy Policy',
                          style: AppTheme.smallTextStyle.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),

                  const SizedBox(height: 32),

                  // Signup Button
                  CustomButton(
                    text: 'Sign Up',
                    onPressed: _signup,
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 1300.ms, duration: 600.ms),

                  const SizedBox(height: 24),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: AppTheme.smallTextStyle,
                      ),
                      TextButton(
                        onPressed: _navigateToLogin,
                        child: Text(
                          'Sign In',
                          style: AppTheme.smallTextStyle.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1400.ms, duration: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
