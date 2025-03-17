import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluette'**
  String get appTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Bluette'**
  String get welcomeMessage;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signupButton;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get errorInvalidEmail;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errorInvalidPassword;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again'**
  String get errorGeneric;

  /// No description provided for @successMessage.
  ///
  /// In en, this message translates to:
  /// **'Operation completed successfully'**
  String get successMessage;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Hey!'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @findPerfectMatch.
  ///
  /// In en, this message translates to:
  /// **'Que des étincelles'**
  String get findPerfectMatch;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials.'**
  String get loginFailed;

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address first'**
  String get enterEmailFirst;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email'**
  String get passwordResetSent;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signupToFindMatch.
  ///
  /// In en, this message translates to:
  /// **'Sign up to find your perfect match'**
  String get signupToFindMatch;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get fullNameLabel;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordHint;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our Terms of Service and Privacy Policy'**
  String get termsAndConditions;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get errorNameRequired;

  /// No description provided for @errorPasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorPasswordMatch;

  /// No description provided for @errorConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get errorConfirmPasswordRequired;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign up. Email may already be in use.'**
  String get errorEmailInUse;

  /// No description provided for @checkEmailConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Please check your email to confirm your account'**
  String get checkEmailConfirmation;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @interestedInLabel.
  ///
  /// In en, this message translates to:
  /// **'Interested In'**
  String get interestedInLabel;

  /// No description provided for @voiceBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice Bio'**
  String get voiceBioLabel;

  /// No description provided for @voiceBioDescription.
  ///
  /// In en, this message translates to:
  /// **'Tell others about yourself in 5-10 seconds'**
  String get voiceBioDescription;

  /// No description provided for @recordVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'Record Voice Bio'**
  String get recordVoiceBio;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @recordAgain.
  ///
  /// In en, this message translates to:
  /// **'Record Again'**
  String get recordAgain;

  /// No description provided for @takePicture.
  ///
  /// In en, this message translates to:
  /// **'Take Picture'**
  String get takePicture;

  /// No description provided for @retakePicture.
  ///
  /// In en, this message translates to:
  /// **'Retake Picture'**
  String get retakePicture;

  /// No description provided for @profilePictureDescription.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of your face to help others recognize you'**
  String get profilePictureDescription;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logoutButton;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGender;

  /// No description provided for @selectPreference.
  ///
  /// In en, this message translates to:
  /// **'Select Preference'**
  String get selectPreference;

  /// No description provided for @playVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'Play Voice Bio'**
  String get playVoiceBio;

  /// No description provided for @stopPlaying.
  ///
  /// In en, this message translates to:
  /// **'Stop Playing'**
  String get stopPlaying;

  /// No description provided for @playingVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get playingVoiceBio;

  /// No description provided for @noVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'No Voice Bio'**
  String get noVoiceBio;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @errorAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 18 and 120'**
  String get errorAgeRange;

  /// No description provided for @errorInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get errorInvalidNumber;

  /// No description provided for @errorFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} cannot be empty'**
  String errorFieldRequired(Object field);

  /// No description provided for @errorSelectValue.
  ///
  /// In en, this message translates to:
  /// **'Please select a value'**
  String get errorSelectValue;

  /// No description provided for @errorUpdateField.
  ///
  /// In en, this message translates to:
  /// **'Failed to update {field}: {error}'**
  String errorUpdateField(Object error, Object field);

  /// No description provided for @errorUpdateProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture: {error}'**
  String errorUpdateProfilePicture(Object error);

  /// No description provided for @errorUpdateVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'Failed to update voice bio: {error}'**
  String errorUpdateVoiceBio(Object error);

  /// No description provided for @errorPlayVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'Failed to play voice bio: {error}'**
  String errorPlayVoiceBio(Object error);

  /// No description provided for @errorNoVoiceBio.
  ///
  /// In en, this message translates to:
  /// **'No voice bio available'**
  String get errorNoVoiceBio;

  /// No description provided for @errorRecordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Recording must be at least 5 seconds long'**
  String get errorRecordingDuration;

  /// No description provided for @errorLogout.
  ///
  /// In en, this message translates to:
  /// **'Failed to log out: {error}'**
  String errorLogout(Object error);

  /// No description provided for @errorDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String errorDeleteAccount(Object error);

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @interestedInMale.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get interestedInMale;

  /// No description provided for @interestedInFemale.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get interestedInFemale;

  /// No description provided for @interestedInEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get interestedInEveryone;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeProfile;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// No description provided for @profilePicture.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture'**
  String get profilePicture;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get tellUsAboutYourself;

  /// No description provided for @basicInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'This information helps us find better matches for you'**
  String get basicInfoDescription;

  /// No description provided for @enterAge.
  ///
  /// In en, this message translates to:
  /// **'Enter your age'**
  String get enterAge;

  /// No description provided for @addProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Add a profile picture'**
  String get addProfilePicture;

  /// No description provided for @errorMicrophonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get errorMicrophonePermission;

  /// No description provided for @errorStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String errorStartRecording(Object error);

  /// No description provided for @errorStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop recording: {error}'**
  String errorStopRecording(Object error);

  /// No description provided for @errorRecordingTooLong.
  ///
  /// In en, this message translates to:
  /// **'Recording was cut to 10 seconds'**
  String get errorRecordingTooLong;

  /// No description provided for @recordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get recordingSaved;

  /// No description provided for @errorCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to create profile. Please try again.'**
  String get errorCreateProfile;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
