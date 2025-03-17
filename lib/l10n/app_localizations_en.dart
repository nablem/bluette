// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bluette';

  @override
  String get welcomeMessage => 'Welcome to Bluette';

  @override
  String get loginButton => 'Login';

  @override
  String get signupButton => 'Sign Up';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get or => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get errorInvalidEmail => 'Please enter a valid email address';

  @override
  String get errorInvalidPassword => 'Password must be at least 6 characters';

  @override
  String get errorGeneric => 'Something went wrong. Please try again';

  @override
  String get successMessage => 'Operation completed successfully';

  @override
  String get welcomeBack => 'Hey!';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get findPerfectMatch => 'Que des étincelles';

  @override
  String get loginFailed => 'Login failed. Please check your credentials.';

  @override
  String get enterEmailFirst => 'Please enter your email address first';

  @override
  String get passwordResetSent => 'Password reset link sent to your email';
}
