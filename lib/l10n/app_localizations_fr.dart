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
  String get signupToFindMatch => 'Inscrivez-vous pour commencer les rencontres';

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

  @override
  String get profileTitle => 'Profil';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get nameLabel => 'Nom';

  @override
  String get ageLabel => 'Âge';

  @override
  String get genderLabel => 'Genre';

  @override
  String get interestedInLabel => 'Intéressé par';

  @override
  String get voiceBioLabel => 'Bio vocale';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get logoutButton => 'Se déconnecter';

  @override
  String get deleteAccountButton => 'Supprimer le compte';

  @override
  String get notSet => 'Non défini';

  @override
  String get edit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get selectGender => 'Sélectionner le genre';

  @override
  String get selectPreference => 'Sélectionner la préférence';

  @override
  String get playVoiceBio => 'Écouter la bio vocale';

  @override
  String get playingVoiceBio => 'Lecture en cours...';

  @override
  String get noVoiceBio => 'Pas de bio vocale';

  @override
  String get deleteAccountTitle => 'Supprimer le compte';

  @override
  String get deleteAccountConfirm => 'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action ne peut pas être annulée.';

  @override
  String get delete => 'Supprimer';

  @override
  String get errorAgeRange => 'L\'âge doit être compris entre 18 et 120 ans';

  @override
  String get errorInvalidNumber => 'Veuillez entrer un nombre valide';

  @override
  String errorFieldRequired(Object field) {
    return '$field ne peut pas être vide';
  }

  @override
  String get errorSelectValue => 'Veuillez sélectionner une valeur';

  @override
  String errorUpdateField(Object error, Object field) {
    return 'Échec de la mise à jour de $field: $error';
  }

  @override
  String errorUpdateProfilePicture(Object error) {
    return 'Échec de la mise à jour de la photo de profil: $error';
  }

  @override
  String errorUpdateVoiceBio(Object error) {
    return 'Échec de la mise à jour de la bio vocale: $error';
  }

  @override
  String errorPlayVoiceBio(Object error) {
    return 'Échec de la lecture de la bio vocale: $error';
  }

  @override
  String get errorNoVoiceBio => 'Pas de bio vocale disponible';

  @override
  String errorLogout(Object error) {
    return 'Échec de la déconnexion: $error';
  }

  @override
  String errorDeleteAccount(Object error) {
    return 'Échec de la suppression du compte: $error';
  }

  @override
  String get genderMale => 'Homme';

  @override
  String get genderFemale => 'Femme';

  @override
  String get genderOther => 'Autre';

  @override
  String get interestedInMale => 'Hommes';

  @override
  String get interestedInFemale => 'Femmes';

  @override
  String get interestedInEveryone => 'Tout le monde';
}
