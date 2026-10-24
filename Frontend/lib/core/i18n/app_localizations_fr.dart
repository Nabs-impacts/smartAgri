// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'SmartAgri';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get forgotPassword => 'Mot de passe oublié';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get phoneInvalid => 'Veuillez saisir un numéro de téléphone valide.';

  @override
  String get passwordRequired => 'Veuillez saisir votre mot de passe.';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordInstructions =>
      'Saisissez votre numéro de téléphone pour recevoir un code de vérification.';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get otpCodeLabel => 'Code de vérification';

  @override
  String get otpCodeHint => 'Code à 6 chiffres';

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String get codeRequired => 'Veuillez saisir le code reçu.';

  @override
  String get codeInvalidLength => 'Le code doit contenir 6 chiffres.';

  @override
  String get passwordMinLength =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get resetSuccess =>
      'Votre mot de passe a été modifié. Vous pouvez vous connecter.';

  @override
  String get codeSent => 'Un code de vérification a été envoyé.';

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get authErrorInvalidCredentials =>
      'Numéro de téléphone ou mot de passe incorrect.';

  @override
  String get authErrorPhoneNotVerified =>
      'Votre numéro de téléphone n\'est pas encore vérifié.';

  @override
  String get authErrorOtpInvalid =>
      'Le code de vérification est invalide ou expiré.';

  @override
  String get authErrorRateLimited =>
      'Trop de tentatives. Veuillez patienter avant de réessayer.';

  @override
  String get authErrorPhoneAlreadyUsed =>
      'Ce numéro de téléphone est déjà utilisé.';

  @override
  String get authErrorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion internet.';

  @override
  String get authErrorTimeout =>
      'Le serveur met trop de temps à répondre. Réessayez.';

  @override
  String get authErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get authErrorInvalidPhone =>
      'Veuillez saisir un numéro de téléphone valide.';

  @override
  String get authErrorAccountDisabled =>
      'Votre compte est désactivé. Contactez le support.';

  @override
  String get errorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion internet.';

  @override
  String get errorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get retry => 'Réessayer';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navProfile => 'Profil';

  @override
  String get homeGreeting => 'Bonjour';

  @override
  String homeWeatherRain(String percent) {
    return 'Risque de pluie ($percent%)';
  }

  @override
  String homeWeatherWind(String speed) {
    return 'Vent ${speed}km/h';
  }

  @override
  String get homeWeatherSoilGood => 'Sol propice';

  @override
  String get homeWeatherSoilDry => 'Sol sec';

  @override
  String get homeWeatherSoilWet => 'Sol humide';

  @override
  String get homeDemoData => 'Données de démonstration';

  @override
  String get homeNewDiagnostic => 'Faire un diagnostic';

  @override
  String get diagnosticComingSoon => 'Le diagnostic arrive à l\'étape suivante';

  @override
  String get searchComingSoon => 'Bientôt disponible';

  @override
  String get profileLanguage => 'Langue';

  @override
  String get profileUsage => 'Mon utilisation';

  @override
  String get profileQuotaPlots => 'parcelles';

  @override
  String get profileQuotaDiagnostics => 'diagnostics ce mois-ci';

  @override
  String get profileQuotaStorage => 'stockage en Mo';

  @override
  String get profileQuotaLlm => 'messages de l\'assistant';

  @override
  String get profileQuotaVideo => 'analyses vidéo';

  @override
  String profileQuotaUnknown(String metric) {
    return 'Utilisation ($metric)';
  }

  @override
  String get profileUnlimited => 'Illimité';

  @override
  String get profileLogout => 'Se déconnecter';

  @override
  String get profileLogoutMessage => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get profileLogoutCancel => 'Annuler';

  @override
  String get profileCachedData => 'Données en cache';
}
