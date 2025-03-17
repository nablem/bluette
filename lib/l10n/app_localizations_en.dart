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

  @override
  String get createAccount => 'Create Account';

  @override
  String get signupToFindMatch => 'Sign up to find your perfect match';

  @override
  String get fullNameLabel => 'First Name';

  @override
  String get enterFullName => 'Enter your full name';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Confirm your password';

  @override
  String get termsAndConditions => 'By signing up, you agree to our Terms of Service and Privacy Policy';

  @override
  String get signIn => 'Sign In';

  @override
  String get errorNameRequired => 'Please enter your name';

  @override
  String get errorPasswordMatch => 'Passwords do not match';

  @override
  String get errorConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get errorEmailInUse => 'Failed to sign up. Email may already be in use.';

  @override
  String get checkEmailConfirmation => 'Please check your email to confirm your account';

  @override
  String get profileTitle => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get nameLabel => 'Name';

  @override
  String get ageLabel => 'Age';

  @override
  String get genderLabel => 'Gender';

  @override
  String get interestedInLabel => 'Interested In';

  @override
  String get voiceBioLabel => 'Voice Bio';

  @override
  String get moreOptions => 'More Options';

  @override
  String get logoutButton => 'Log Out';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get notSet => 'Not set';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get selectGender => 'Select Gender';

  @override
  String get selectPreference => 'Select Preference';

  @override
  String get playVoiceBio => 'Play Voice Bio';

  @override
  String get playingVoiceBio => 'Playing...';

  @override
  String get noVoiceBio => 'No Voice Bio';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirm => 'Are you sure you want to delete your account? This action cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get errorAgeRange => 'Age must be between 18 and 120';

  @override
  String get errorInvalidNumber => 'Please enter a valid number';

  @override
  String errorFieldRequired(Object field) {
    return '$field cannot be empty';
  }

  @override
  String get errorSelectValue => 'Please select a value';

  @override
  String errorUpdateField(Object error, Object field) {
    return 'Failed to update $field: $error';
  }

  @override
  String errorUpdateProfilePicture(Object error) {
    return 'Failed to update profile picture: $error';
  }

  @override
  String errorUpdateVoiceBio(Object error) {
    return 'Failed to update voice bio: $error';
  }

  @override
  String errorPlayVoiceBio(Object error) {
    return 'Failed to play voice bio: $error';
  }

  @override
  String get errorNoVoiceBio => 'No voice bio available';

  @override
  String errorLogout(Object error) {
    return 'Failed to log out: $error';
  }

  @override
  String errorDeleteAccount(Object error) {
    return 'Failed to delete account: $error';
  }
}
