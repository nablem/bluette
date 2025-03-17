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
  String get voiceBioDescription => 'Tell others about yourself in 5-10 seconds';

  @override
  String get recordVoiceBio => 'Record Voice Bio';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get recordAgain => 'Record Again';

  @override
  String get takePicture => 'Take Picture';

  @override
  String get retakePicture => 'Retake Picture';

  @override
  String get profilePictureDescription => 'Take a clear photo of your face to help others recognize you';

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
  String get stopPlaying => 'Stop Playing';

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
  String get errorRecordingDuration => 'Recording must be at least 5 seconds long';

  @override
  String errorLogout(Object error) {
    return 'Failed to log out: $error';
  }

  @override
  String errorDeleteAccount(Object error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get interestedInMale => 'Men';

  @override
  String get interestedInFemale => 'Women';

  @override
  String get interestedInEveryone => 'Everyone';

  @override
  String get completeProfile => 'Complete Your Profile';

  @override
  String get basicInfo => 'Basic Info';

  @override
  String get profilePicture => 'Profile Picture';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish';

  @override
  String get tellUsAboutYourself => 'Tell us about yourself';

  @override
  String get basicInfoDescription => 'This information helps us find better matches for you';

  @override
  String get enterAge => 'Enter your age';

  @override
  String get addProfilePicture => 'Add a profile picture';

  @override
  String get errorMicrophonePermission => 'Microphone permission denied';

  @override
  String errorStartRecording(Object error) {
    return 'Failed to start recording: $error';
  }

  @override
  String errorStopRecording(Object error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String get errorRecordingTooLong => 'Recording was cut to 10 seconds';

  @override
  String get recordingSaved => 'Recording saved';

  @override
  String get errorCreateProfile => 'Failed to create profile. Please try again.';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get noInternetConnectionMessage => 'No internet connection. Please check your network and try again';

  @override
  String get filterProfiles => 'Filter Profiles';

  @override
  String get ageRange => 'Age Range';

  @override
  String maximumDistance(Object distance) {
    return 'Maximum Distance ($distance km)';
  }

  @override
  String get applyFilters => 'Apply Filters';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get recentlyMet => 'You recently met';

  @override
  String get aboutToMeet => 'You\'re about to meet';

  @override
  String get someone => 'someone';

  @override
  String get showOnMap => 'Show on the map';

  @override
  String get cancelMeetup => 'Cancel Meetup?';

  @override
  String get cancelMeetupConfirm => 'Are you sure? You may lose visibility.';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get returnToSwiping => 'Return to Swiping';

  @override
  String wantsToSeeYou(Object name) {
    return '$name wants to see you!';
  }

  @override
  String get weSetUpDate => 'We set up a date for you,\nHave fun!';

  @override
  String get allRight => 'All right!';

  @override
  String get weRememberSeen => 'We\'ll remember you\'ve seen this match!';

  @override
  String get locationAccessRequired => 'Location Access Required';

  @override
  String get locationAccessDescription => 'We need your location to show you nearby profiles. Please enable location services and grant permission.';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get openLocationSettings => 'Open Location Settings';

  @override
  String get openAppSettings => 'Open App Settings';

  @override
  String get noMoreProfiles => 'No more profiles to show';

  @override
  String get noProfilesDescription => 'You\'ve seen all profiles that match your current preferences. Try adjusting your filters or check back later for new users.';

  @override
  String get adjustFilters => 'Adjust Filters';

  @override
  String get refresh => 'Refresh';

  @override
  String get loadingMoreProfiles => 'Loading more profiles...';

  @override
  String get swipesNotSaved => 'Your swipes may not have been saved due to connection issues.';
}
