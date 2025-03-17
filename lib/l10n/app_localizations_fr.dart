// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Bluette';

  @override
  String get welcomeMessage => 'Bienvenue sur Bluette';

  @override
  String get loginButton => 'Connexion';

  @override
  String get signupButton => 'S\'inscrire';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get or => 'ou';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte ?';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get errorInvalidEmail => 'Veuillez entrer une adresse email valide';

  @override
  String get errorInvalidPassword => 'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get errorGeneric => 'Une erreur est survenue. Veuillez réessayer';

  @override
  String get successMessage => 'Opération réussie';

  @override
  String get welcomeBack => 'Hey !';

  @override
  String get signInToContinue => 'Connectez-vous pour continuer';

  @override
  String get findPerfectMatch => 'Que des étincelles';

  @override
  String get loginFailed => 'La connexion a échoué. Veuillez vérifier vos identifiants.';

  @override
  String get enterEmailFirst => 'Veuillez d\'abord entrer votre adresse email';

  @override
  String get passwordResetSent => 'Le lien de réinitialisation du mot de passe a été envoyé à votre email';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signupToFindMatch => 'Inscrivez-vous pour trouver votre âme sœur';

  @override
  String get fullNameLabel => 'Prénom';

  @override
  String get enterFullName => 'Entrez votre nom complet';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get confirmPasswordHint => 'Confirmez votre mot de passe';

  @override
  String get termsAndConditions => 'En vous inscrivant, vous acceptez nos Conditions d\'utilisation et notre Politique de confidentialité';

  @override
  String get signIn => 'Se connecter';

  @override
  String get errorNameRequired => 'Veuillez entrer votre nom';

  @override
  String get errorPasswordMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get errorConfirmPasswordRequired => 'Veuillez confirmer votre mot de passe';

  @override
  String get errorEmailInUse => 'L\'inscription a échoué. L\'email est peut-être déjà utilisé.';

  @override
  String get checkEmailConfirmation => 'Veuillez vérifier votre email pour confirmer votre compte';
}
