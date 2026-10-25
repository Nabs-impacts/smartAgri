// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Zarma (`dje`).
class AppLocalizationsDje extends AppLocalizations {
  AppLocalizationsDje([String locale = 'dje']) : super(locale);

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

  @override
  String get homeFarmsTitle => 'Mes exploitations';

  @override
  String get homeFarmsSeeAll => 'Tout voir';

  @override
  String get homeFarmsEmpty => 'Ajoutez votre première exploitation';

  @override
  String get farmsTitle => 'Mes exploitations';

  @override
  String get farmsEmpty => 'Aucune exploitation pour le moment.';

  @override
  String get farmAdd => 'Ajouter une exploitation';

  @override
  String get farmCreateTitle => 'Nouvelle exploitation';

  @override
  String get farmEditTitle => 'Modifier l\'exploitation';

  @override
  String get farmNameLabel => 'Nom de l\'exploitation';

  @override
  String get farmVillageLabel => 'Village';

  @override
  String get farmRegionLabel => 'Région';

  @override
  String get farmRegionNone => 'Aucune région';

  @override
  String get farmNameLength =>
      'Le nom doit contenir entre 2 et 120 caractères.';

  @override
  String get farmSave => 'Enregistrer';

  @override
  String get farmEdit => 'Modifier';

  @override
  String get farmDelete => 'Supprimer';

  @override
  String get farmDeleteTitle => 'Supprimer l\'exploitation ?';

  @override
  String get farmDeleteMessage =>
      'Cette action supprimera aussi toutes les parcelles associées.';

  @override
  String get farmDetailsTitle => 'Exploitation';

  @override
  String get farmNotFound => 'Exploitation introuvable.';

  @override
  String get plotAdd => 'Ajouter une parcelle';

  @override
  String get plotsTitle => 'Parcelles';

  @override
  String get plotsEmpty => 'Aucune parcelle pour le moment.';

  @override
  String get plotCreateTitle => 'Nouvelle parcelle';

  @override
  String get plotEditTitle => 'Modifier la parcelle';

  @override
  String get plotNameLabel => 'Nom de la parcelle';

  @override
  String get plotNameLength =>
      'Le nom doit contenir entre 2 et 120 caractères.';

  @override
  String get plotAreaLabel => 'Surface (hectares)';

  @override
  String get plotAreaHint => 'Ex. 2,5';

  @override
  String get plotAreaInvalid =>
      'La surface doit être supérieure à 0 et au plus 10000.';

  @override
  String get plotSoilLabel => 'Type de sol';

  @override
  String get plotIrrigationLabel => 'Irrigation';

  @override
  String get plotMapComingSoon =>
      'Le tracé de la parcelle sur la carte arrivera plus tard';

  @override
  String get plotDeleteTitle => 'Supprimer la parcelle ?';

  @override
  String get plotDeleteMessage =>
      'Voulez-vous vraiment supprimer cette parcelle ?';

  @override
  String get plotDetailsTitle => 'Parcelle';

  @override
  String get plotNotFound => 'Parcelle introuvable.';

  @override
  String get plotCyclesTitle => 'Cycles de culture';

  @override
  String get plotDiagnosticsTitle => 'Diagnostics';

  @override
  String get comingSoon => 'Disponible prochainement';

  @override
  String get cancel => 'Annuler';

  @override
  String get errorTimeout =>
      'Le serveur met trop de temps à répondre. Réessayez.';

  @override
  String get errorNotFound => 'L\'élément demandé est introuvable.';

  @override
  String get errorConflict =>
      'Cette action entre en conflit avec des données existantes.';

  @override
  String errorQuotaExceeded(String limit) {
    return 'Vous avez atteint la limite de votre formule ($limit parcelles).';
  }

  @override
  String get diagnosticNewTitle => 'Nouveau diagnostic';

  @override
  String get diagnosticTipsTitle => 'Conseils pour une bonne photo';

  @override
  String get diagnosticTipClose =>
      'Photographiez de près une feuille ou un fruit touché';

  @override
  String get diagnosticTipLight => 'Préférez la lumière du jour, sans ombre';

  @override
  String get diagnosticTipOnePlant =>
      'Une seule plante par photo, jusqu\'à 3 photos';

  @override
  String get diagnosticCropLabel => 'Culture (facultatif)';

  @override
  String get diagnosticPlotLabel => 'Parcelle (facultatif)';

  @override
  String get diagnosticPhotosTitle => 'Photos';

  @override
  String get diagnosticTakePhoto => 'Prendre une photo';

  @override
  String get diagnosticChooseGallery => 'Choisir dans la galerie';

  @override
  String get diagnosticAnalyze => 'Analyser';

  @override
  String get diagnosticPhotoUnsupported =>
      'Format d\'image non pris en charge.';

  @override
  String get diagnosticPhotoError => 'Impossible de traiter cette photo.';

  @override
  String get diagnosticPhotoDelete => 'Supprimer la photo';

  @override
  String get diagnosticPhotoAdd => 'Ajouter une photo';

  @override
  String get diagnosticQuotaReached =>
      'Vous avez atteint la limite de diagnostics de ce mois';

  @override
  String get diagnosticUploading => 'Envoi des photos…';

  @override
  String get diagnosticExitTitle => 'Quitter l\'envoi ?';

  @override
  String get diagnosticExitMessage =>
      'L\'envoi est en cours. Voulez-vous vraiment quitter ?';

  @override
  String get diagnosticExitConfirm => 'Quitter';

  @override
  String get diagnosticResultTitle => 'Résultat du diagnostic';

  @override
  String get diagnosticDemoBanner =>
      'Résultat de démonstration : l\'analyse est simulée.';

  @override
  String get diagnosticProcessing => 'Analyse en cours…';

  @override
  String get diagnosticProcessingHint => 'Cela prend quelques secondes';

  @override
  String get diagnosticOtherPossibilities => 'Autres possibilités';

  @override
  String get diagnosticAdvice => 'Conseils';

  @override
  String get diagnosticTechnician =>
      'Consultez un technicien agricole avant tout traitement.';

  @override
  String get diagnosticHealthy => 'Culture saine';

  @override
  String get diagnosticExpertReview => 'Un expert vérifie ce résultat';

  @override
  String get diagnosticProvisional => 'Prédictions provisoires';

  @override
  String get diagnosticFailed => 'L\'analyse a échoué.';

  @override
  String get diagnosticNewDiagnostic => 'Nouveau diagnostic';

  @override
  String get diagnosticTimeout => 'L\'analyse prend plus de temps que prévu';

  @override
  String get diagnosticRefresh => 'Actualiser';

  @override
  String get diagnosticFeedbackQuestion => 'Ce conseil vous a-t-il aidé ?';

  @override
  String get diagnosticFeedbackYes => 'Oui';

  @override
  String get diagnosticFeedbackNo => 'Non';

  @override
  String get diagnosticFeedbackThanks => 'Merci pour votre retour.';

  @override
  String get diagnosticDelete => 'Supprimer ce diagnostic';

  @override
  String get diagnosticDeleteTitle => 'Supprimer le diagnostic ?';

  @override
  String get diagnosticDeleteMessage =>
      'Voulez-vous vraiment supprimer ce diagnostic ?';

  @override
  String get diagnosticSeverityLow => 'Faible';

  @override
  String get diagnosticSeverityMedium => 'Moyenne';

  @override
  String get diagnosticSeverityHigh => 'Élevée';

  @override
  String diagnosticConfidence(String percent) {
    return 'Confiance $percent %';
  }

  @override
  String get diagnosticStepCultural => 'Pratiques culturales';

  @override
  String get diagnosticStepBiological => 'Lutte biologique';

  @override
  String get diagnosticStepChemical => 'Traitement';

  @override
  String get diagnosticStepPrevention => 'Prévention';

  @override
  String get diagnosticsHistoryTitle => 'Mes diagnostics';

  @override
  String get diagnosticsHistorySeeAll => 'Tout voir';

  @override
  String get diagnosticsHistoryEmpty => 'Aucun diagnostic pour l\'instant';

  @override
  String get diagnosticsHistoryNew => 'Faire un diagnostic';

  @override
  String get diagnosticsHistoryUntitled => 'Analyse en cours…';

  @override
  String get diagnosticsLatestTitle => 'Derniers diagnostics';

  @override
  String get diagnosticsLatestEmpty => 'Vos diagnostics apparaîtront ici';

  @override
  String get diagnosticsHistoryDelete => 'Supprimer';

  @override
  String get diagnosticStatusDone => 'Terminé';

  @override
  String get diagnosticStatusNeedsReview => 'À vérifier';

  @override
  String get diagnosticStatusFailed => 'Échec';

  @override
  String get diagnosticStatusInProgress => 'En cours';

  @override
  String get profileDiagnostics => 'Mes diagnostics';
}
