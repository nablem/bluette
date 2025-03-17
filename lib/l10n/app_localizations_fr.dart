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
  String get voiceBioDescription => 'Parlez de vous en 5-10 secondes';

  @override
  String get recordVoiceBio => 'Enregistrer une bio vocale';

  @override
  String get stopRecording => 'Arrêter l\'enregistrement';

  @override
  String get recordAgain => 'Réenregistrer';

  @override
  String get takePicture => 'Prendre une photo';

  @override
  String get retakePicture => 'Reprendre la photo';

  @override
  String get profilePictureDescription => 'Prenez une photo claire de votre visage pour aider les autres à vous reconnaître';

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
  String get stopPlaying => 'Arrêter la lecture';

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
  String get errorRecordingDuration => 'L\'enregistrement doit durer au moins 5 secondes';

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

  @override
  String get completeProfile => 'Complétez votre profil';

  @override
  String get basicInfo => 'Informations de base';

  @override
  String get profilePicture => 'Photo de profil';

  @override
  String get next => 'Suivant';

  @override
  String get finish => 'Terminer';

  @override
  String get tellUsAboutYourself => 'Parlez-nous de vous';

  @override
  String get basicInfoDescription => 'Ces informations nous aident à trouver de meilleures correspondances pour vous';

  @override
  String get enterAge => 'Entrez votre âge';

  @override
  String get addProfilePicture => 'Ajouter une photo de profil';

  @override
  String get errorMicrophonePermission => 'Permission du microphone refusée';

  @override
  String errorStartRecording(Object error) {
    return 'Échec du démarrage de l\'enregistrement : $error';
  }

  @override
  String errorStopRecording(Object error) {
    return 'Échec de l\'arrêt de l\'enregistrement : $error';
  }

  @override
  String get errorRecordingTooLong => 'L\'enregistrement a été limité à 10 secondes';

  @override
  String get recordingSaved => 'Sauvegardé';

  @override
  String get errorCreateProfile => 'Échec de la création du profil. Veuillez réessayer.';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get noInternetConnection => 'Pas de connexion Internet';

  @override
  String get noInternetConnectionMessage => 'Pas de connexion Internet. Veuillez vérifier votre réseau et réessayer';

  @override
  String get filterProfiles => 'Filtrer les profils';

  @override
  String get ageRange => 'Tranche d\'âge';

  @override
  String maximumDistance(Object distance) {
    return 'Distance maximale ($distance km)';
  }

  @override
  String get applyFilters => 'Appliquer les filtres';

  @override
  String get resetToDefault => 'Réinitialiser';

  @override
  String get recentlyMet => 'Vous avez récemment rencontré';

  @override
  String get aboutToMeet => 'Vous allez rencontrer';

  @override
  String get someone => 'quelqu\'un';

  @override
  String get showOnMap => 'Voir sur la carte';

  @override
  String get cancelMeetup => 'Annuler le rendez-vous ?';

  @override
  String get cancelMeetupConfirm => 'Êtes-vous sûr ? Vous risquez de perdre de la visibilité.';

  @override
  String get no => 'Non';

  @override
  String get yes => 'Oui';

  @override
  String get returnToSwiping => 'Retourner au swipe';

  @override
  String wantsToSeeYou(Object name) {
    return '$name veut vous voir !';
  }

  @override
  String get weSetUpDate => 'Nous avons organisé un rendez-vous pour vous,\nAmusez-vous bien !';

  @override
  String get allRight => 'D\'accord !';

  @override
  String get weRememberSeen => 'Nous nous souviendrons que vous avez vu ce match !';

  @override
  String get locationAccessRequired => 'Accès à la localisation requis';

  @override
  String get locationAccessDescription => 'Nous avons besoin de votre localisation pour vous montrer les profils à proximité. Veuillez activer les services de localisation et donner l\'autorisation.';

  @override
  String get grantPermission => 'Donner l\'autorisation';

  @override
  String get openLocationSettings => 'Ouvrir les paramètres de localisation';

  @override
  String get openAppSettings => 'Ouvrir les paramètres de l\'application';

  @override
  String get noMoreProfiles => 'Plus de profils à afficher';

  @override
  String get noProfilesDescription => 'Vous avez vu tous les profils qui correspondent à vos préférences actuelles. Essayez d\'ajuster vos filtres ou revenez plus tard pour voir de nouveaux utilisateurs.';

  @override
  String get adjustFilters => 'Ajuster les filtres';

  @override
  String get refresh => 'Actualiser';

  @override
  String get loadingMoreProfiles => 'Chargement de plus de profils...';

  @override
  String get swipesNotSaved => 'Vos swipes n\'ont peut-être pas été enregistrés en raison de problèmes de connexion.';
}
