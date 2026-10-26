import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_dje.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ha.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'i18n/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('dje'),
    Locale('fr'),
    Locale('ha'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'SmartAgri'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In fr, this message translates to:
  /// **'Se souvenir de moi'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @phoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro de téléphone valide.'**
  String get phoneInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre mot de passe.'**
  String get passwordRequired;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre numéro de téléphone pour recevoir un code de vérification.'**
  String get forgotPasswordInstructions;

  /// No description provided for @sendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get sendCode;

  /// No description provided for @otpCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification'**
  String get otpCodeLabel;

  /// No description provided for @otpCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Code à 6 chiffres'**
  String get otpCodeHint;

  /// No description provided for @newPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPasswordLabel;

  /// No description provided for @changePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get changePassword;

  /// No description provided for @resendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get resendCode;

  /// No description provided for @codeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir le code reçu.'**
  String get codeRequired;

  /// No description provided for @codeInvalidLength.
  ///
  /// In fr, this message translates to:
  /// **'Le code doit contenir 6 chiffres.'**
  String get codeInvalidLength;

  /// No description provided for @passwordMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 8 caractères.'**
  String get passwordMinLength;

  /// No description provided for @passwordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas.'**
  String get passwordMismatch;

  /// No description provided for @resetSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Votre mot de passe a été modifié. Vous pouvez vous connecter.'**
  String get resetSuccess;

  /// No description provided for @codeSent.
  ///
  /// In fr, this message translates to:
  /// **'Un code de vérification a été envoyé.'**
  String get codeSent;

  /// No description provided for @backToLogin.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get backToLogin;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone ou mot de passe incorrect.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorPhoneNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro de téléphone n\'est pas encore vérifié.'**
  String get authErrorPhoneNotVerified;

  /// No description provided for @authErrorOtpInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le code de vérification est invalide ou expiré.'**
  String get authErrorOtpInvalid;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Veuillez patienter avant de réessayer.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorPhoneAlreadyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro de téléphone est déjà utilisé.'**
  String get authErrorPhoneAlreadyUsed;

  /// No description provided for @authErrorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Vérifiez votre connexion internet.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met trop de temps à répondre. Réessayez.'**
  String get authErrorTimeout;

  /// No description provided for @authErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro de téléphone valide.'**
  String get authErrorInvalidPhone;

  /// No description provided for @authErrorAccountDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est désactivé. Contactez le support.'**
  String get authErrorAccountDisabled;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Vérifiez votre connexion internet.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get navSearch;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeGreeting;

  /// No description provided for @homeWeatherRain.
  ///
  /// In fr, this message translates to:
  /// **'Risque de pluie ({percent}%)'**
  String homeWeatherRain(String percent);

  /// No description provided for @homeWeatherWind.
  ///
  /// In fr, this message translates to:
  /// **'Vent {speed}km/h'**
  String homeWeatherWind(String speed);

  /// No description provided for @homeWeatherSoilGood.
  ///
  /// In fr, this message translates to:
  /// **'Sol propice'**
  String get homeWeatherSoilGood;

  /// No description provided for @homeWeatherSoilDry.
  ///
  /// In fr, this message translates to:
  /// **'Sol sec'**
  String get homeWeatherSoilDry;

  /// No description provided for @homeWeatherSoilWet.
  ///
  /// In fr, this message translates to:
  /// **'Sol humide'**
  String get homeWeatherSoilWet;

  /// No description provided for @homeDemoData.
  ///
  /// In fr, this message translates to:
  /// **'Données de démonstration'**
  String get homeDemoData;

  /// No description provided for @homeNewDiagnostic.
  ///
  /// In fr, this message translates to:
  /// **'Faire un diagnostic'**
  String get homeNewDiagnostic;

  /// No description provided for @diagnosticComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Le diagnostic arrive à l\'étape suivante'**
  String get diagnosticComingSoon;

  /// No description provided for @searchComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get searchComingSoon;

  /// No description provided for @profileLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileLanguage;

  /// No description provided for @profileUsage.
  ///
  /// In fr, this message translates to:
  /// **'Mon utilisation'**
  String get profileUsage;

  /// No description provided for @profileQuotaPlots.
  ///
  /// In fr, this message translates to:
  /// **'parcelles'**
  String get profileQuotaPlots;

  /// No description provided for @profileQuotaDiagnostics.
  ///
  /// In fr, this message translates to:
  /// **'diagnostics ce mois-ci'**
  String get profileQuotaDiagnostics;

  /// No description provided for @profileQuotaStorage.
  ///
  /// In fr, this message translates to:
  /// **'stockage en Mo'**
  String get profileQuotaStorage;

  /// No description provided for @profileQuotaLlm.
  ///
  /// In fr, this message translates to:
  /// **'messages de l\'assistant'**
  String get profileQuotaLlm;

  /// No description provided for @profileQuotaVideo.
  ///
  /// In fr, this message translates to:
  /// **'analyses vidéo'**
  String get profileQuotaVideo;

  /// No description provided for @profileQuotaUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Utilisation ({metric})'**
  String profileQuotaUnknown(String metric);

  /// No description provided for @profileUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'Illimité'**
  String get profileUnlimited;

  /// No description provided for @profileLogout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileLogout;

  /// No description provided for @profileLogoutMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment vous déconnecter ?'**
  String get profileLogoutMessage;

  /// No description provided for @profileLogoutCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get profileLogoutCancel;

  /// No description provided for @profileCachedData.
  ///
  /// In fr, this message translates to:
  /// **'Données en cache'**
  String get profileCachedData;

  /// No description provided for @homeFarmsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes exploitations'**
  String get homeFarmsTitle;

  /// No description provided for @homeFarmsSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get homeFarmsSeeAll;

  /// No description provided for @homeFarmsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre première exploitation'**
  String get homeFarmsEmpty;

  /// No description provided for @farmsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes exploitations'**
  String get farmsTitle;

  /// No description provided for @farmsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune exploitation pour le moment.'**
  String get farmsEmpty;

  /// No description provided for @farmAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une exploitation'**
  String get farmAdd;

  /// No description provided for @farmCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle exploitation'**
  String get farmCreateTitle;

  /// No description provided for @farmEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'exploitation'**
  String get farmEditTitle;

  /// No description provided for @farmNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'exploitation'**
  String get farmNameLabel;

  /// No description provided for @farmVillageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Village'**
  String get farmVillageLabel;

  /// No description provided for @farmRegionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Région'**
  String get farmRegionLabel;

  /// No description provided for @farmRegionNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune région'**
  String get farmRegionNone;

  /// No description provided for @farmNameLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir entre 2 et 120 caractères.'**
  String get farmNameLength;

  /// No description provided for @farmSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get farmSave;

  /// No description provided for @farmEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get farmEdit;

  /// No description provided for @farmDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get farmDelete;

  /// No description provided for @farmDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'exploitation ?'**
  String get farmDeleteTitle;

  /// No description provided for @farmDeleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action supprimera aussi toutes les parcelles associées.'**
  String get farmDeleteMessage;

  /// No description provided for @farmDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Exploitation'**
  String get farmDetailsTitle;

  /// No description provided for @farmNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Exploitation introuvable.'**
  String get farmNotFound;

  /// No description provided for @plotAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une parcelle'**
  String get plotAdd;

  /// No description provided for @plotsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcelles'**
  String get plotsTitle;

  /// No description provided for @plotsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune parcelle pour le moment.'**
  String get plotsEmpty;

  /// No description provided for @plotCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle parcelle'**
  String get plotCreateTitle;

  /// No description provided for @plotEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la parcelle'**
  String get plotEditTitle;

  /// No description provided for @plotNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la parcelle'**
  String get plotNameLabel;

  /// No description provided for @plotNameLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir entre 2 et 120 caractères.'**
  String get plotNameLength;

  /// No description provided for @plotAreaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Surface (hectares)'**
  String get plotAreaLabel;

  /// No description provided for @plotAreaHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 2,5'**
  String get plotAreaHint;

  /// No description provided for @plotAreaInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La surface doit être supérieure à 0 et au plus 10000.'**
  String get plotAreaInvalid;

  /// No description provided for @plotSoilLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de sol'**
  String get plotSoilLabel;

  /// No description provided for @plotIrrigationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Irrigation'**
  String get plotIrrigationLabel;

  /// No description provided for @plotMapComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Le tracé de la parcelle sur la carte arrivera plus tard'**
  String get plotMapComingSoon;

  /// No description provided for @plotDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la parcelle ?'**
  String get plotDeleteTitle;

  /// No description provided for @plotDeleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette parcelle ?'**
  String get plotDeleteMessage;

  /// No description provided for @plotDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcelle'**
  String get plotDetailsTitle;

  /// No description provided for @plotNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Parcelle introuvable.'**
  String get plotNotFound;

  /// No description provided for @plotCyclesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cycles de culture'**
  String get plotCyclesTitle;

  /// No description provided for @plotDiagnosticsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostics'**
  String get plotDiagnosticsTitle;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Disponible prochainement'**
  String get comingSoon;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @errorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met trop de temps à répondre. Réessayez.'**
  String get errorTimeout;

  /// No description provided for @errorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'L\'élément demandé est introuvable.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In fr, this message translates to:
  /// **'Cette action entre en conflit avec des données existantes.'**
  String get errorConflict;

  /// No description provided for @errorQuotaExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint la limite de votre formule ({limit} parcelles).'**
  String errorQuotaExceeded(String limit);

  /// No description provided for @diagnosticNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau diagnostic'**
  String get diagnosticNewTitle;

  /// No description provided for @diagnosticTipsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conseils pour une bonne photo'**
  String get diagnosticTipsTitle;

  /// No description provided for @diagnosticTipClose.
  ///
  /// In fr, this message translates to:
  /// **'Photographiez de près une feuille ou un fruit touché'**
  String get diagnosticTipClose;

  /// No description provided for @diagnosticTipLight.
  ///
  /// In fr, this message translates to:
  /// **'Préférez la lumière du jour, sans ombre'**
  String get diagnosticTipLight;

  /// No description provided for @diagnosticTipOnePlant.
  ///
  /// In fr, this message translates to:
  /// **'Une seule plante par photo, jusqu\'à 3 photos'**
  String get diagnosticTipOnePlant;

  /// No description provided for @diagnosticCropLabel.
  ///
  /// In fr, this message translates to:
  /// **'Culture (facultatif)'**
  String get diagnosticCropLabel;

  /// No description provided for @diagnosticPlotLabel.
  ///
  /// In fr, this message translates to:
  /// **'Parcelle (facultatif)'**
  String get diagnosticPlotLabel;

  /// No description provided for @diagnosticPhotosTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get diagnosticPhotosTitle;

  /// No description provided for @diagnosticTakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get diagnosticTakePhoto;

  /// No description provided for @diagnosticChooseGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get diagnosticChooseGallery;

  /// No description provided for @diagnosticAnalyze.
  ///
  /// In fr, this message translates to:
  /// **'Analyser'**
  String get diagnosticAnalyze;

  /// No description provided for @diagnosticPhotoUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Format d\'image non pris en charge.'**
  String get diagnosticPhotoUnsupported;

  /// No description provided for @diagnosticPhotoError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de traiter cette photo.'**
  String get diagnosticPhotoError;

  /// No description provided for @diagnosticPhotoDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get diagnosticPhotoDelete;

  /// No description provided for @diagnosticPhotoAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get diagnosticPhotoAdd;

  /// No description provided for @diagnosticQuotaReached.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint la limite de diagnostics de ce mois'**
  String get diagnosticQuotaReached;

  /// No description provided for @diagnosticUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi des photos…'**
  String get diagnosticUploading;

  /// No description provided for @diagnosticExitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter l\'envoi ?'**
  String get diagnosticExitTitle;

  /// No description provided for @diagnosticExitMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'envoi est en cours. Voulez-vous vraiment quitter ?'**
  String get diagnosticExitMessage;

  /// No description provided for @diagnosticExitConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get diagnosticExitConfirm;

  /// No description provided for @diagnosticResultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résultat du diagnostic'**
  String get diagnosticResultTitle;

  /// No description provided for @diagnosticDemoBanner.
  ///
  /// In fr, this message translates to:
  /// **'Résultat de démonstration : l\'analyse est simulée.'**
  String get diagnosticDemoBanner;

  /// No description provided for @diagnosticProcessing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours…'**
  String get diagnosticProcessing;

  /// No description provided for @diagnosticProcessingHint.
  ///
  /// In fr, this message translates to:
  /// **'Cela prend quelques secondes'**
  String get diagnosticProcessingHint;

  /// No description provided for @diagnosticOtherPossibilities.
  ///
  /// In fr, this message translates to:
  /// **'Autres possibilités'**
  String get diagnosticOtherPossibilities;

  /// No description provided for @diagnosticAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Conseils'**
  String get diagnosticAdvice;

  /// No description provided for @diagnosticTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Consultez un technicien agricole avant tout traitement.'**
  String get diagnosticTechnician;

  /// No description provided for @diagnosticHealthy.
  ///
  /// In fr, this message translates to:
  /// **'Culture saine'**
  String get diagnosticHealthy;

  /// No description provided for @diagnosticExpertReview.
  ///
  /// In fr, this message translates to:
  /// **'Un expert vérifie ce résultat'**
  String get diagnosticExpertReview;

  /// No description provided for @diagnosticProvisional.
  ///
  /// In fr, this message translates to:
  /// **'Prédictions provisoires'**
  String get diagnosticProvisional;

  /// No description provided for @diagnosticFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse a échoué.'**
  String get diagnosticFailed;

  /// No description provided for @diagnosticNewDiagnostic.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau diagnostic'**
  String get diagnosticNewDiagnostic;

  /// No description provided for @diagnosticTimeout.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse prend plus de temps que prévu'**
  String get diagnosticTimeout;

  /// No description provided for @diagnosticRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get diagnosticRefresh;

  /// No description provided for @diagnosticFeedbackQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Ce conseil vous a-t-il aidé ?'**
  String get diagnosticFeedbackQuestion;

  /// No description provided for @diagnosticFeedbackYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get diagnosticFeedbackYes;

  /// No description provided for @diagnosticFeedbackNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get diagnosticFeedbackNo;

  /// No description provided for @diagnosticFeedbackThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre retour.'**
  String get diagnosticFeedbackThanks;

  /// No description provided for @diagnosticDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce diagnostic'**
  String get diagnosticDelete;

  /// No description provided for @diagnosticDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le diagnostic ?'**
  String get diagnosticDeleteTitle;

  /// No description provided for @diagnosticDeleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ce diagnostic ?'**
  String get diagnosticDeleteMessage;

  /// No description provided for @diagnosticSeverityLow.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get diagnosticSeverityLow;

  /// No description provided for @diagnosticSeverityMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get diagnosticSeverityMedium;

  /// No description provided for @diagnosticSeverityHigh.
  ///
  /// In fr, this message translates to:
  /// **'Élevée'**
  String get diagnosticSeverityHigh;

  /// No description provided for @diagnosticConfidence.
  ///
  /// In fr, this message translates to:
  /// **'Confiance {percent} %'**
  String diagnosticConfidence(String percent);

  /// No description provided for @diagnosticStepCultural.
  ///
  /// In fr, this message translates to:
  /// **'Pratiques culturales'**
  String get diagnosticStepCultural;

  /// No description provided for @diagnosticStepBiological.
  ///
  /// In fr, this message translates to:
  /// **'Lutte biologique'**
  String get diagnosticStepBiological;

  /// No description provided for @diagnosticStepChemical.
  ///
  /// In fr, this message translates to:
  /// **'Traitement'**
  String get diagnosticStepChemical;

  /// No description provided for @diagnosticStepPrevention.
  ///
  /// In fr, this message translates to:
  /// **'Prévention'**
  String get diagnosticStepPrevention;

  /// No description provided for @diagnosticsHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes diagnostics'**
  String get diagnosticsHistoryTitle;

  /// No description provided for @diagnosticsHistorySeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get diagnosticsHistorySeeAll;

  /// No description provided for @diagnosticsHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun diagnostic pour l\'instant'**
  String get diagnosticsHistoryEmpty;

  /// No description provided for @diagnosticsHistoryNew.
  ///
  /// In fr, this message translates to:
  /// **'Faire un diagnostic'**
  String get diagnosticsHistoryNew;

  /// No description provided for @diagnosticsHistoryUntitled.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours…'**
  String get diagnosticsHistoryUntitled;

  /// No description provided for @diagnosticsLatestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Derniers diagnostics'**
  String get diagnosticsLatestTitle;

  /// No description provided for @diagnosticsLatestEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vos diagnostics apparaîtront ici'**
  String get diagnosticsLatestEmpty;

  /// No description provided for @diagnosticsHistoryDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get diagnosticsHistoryDelete;

  /// No description provided for @diagnosticStatusDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get diagnosticStatusDone;

  /// No description provided for @diagnosticStatusNeedsReview.
  ///
  /// In fr, this message translates to:
  /// **'À vérifier'**
  String get diagnosticStatusNeedsReview;

  /// No description provided for @diagnosticStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get diagnosticStatusFailed;

  /// No description provided for @diagnosticStatusInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get diagnosticStatusInProgress;

  /// No description provided for @profileDiagnostics.
  ///
  /// In fr, this message translates to:
  /// **'Mes diagnostics'**
  String get profileDiagnostics;

  /// No description provided for @adminNavOverview.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get adminNavOverview;

  /// No description provided for @adminNavYields.
  ///
  /// In fr, this message translates to:
  /// **'Rendements'**
  String get adminNavYields;

  /// No description provided for @adminOverviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get adminOverviewTitle;

  /// No description provided for @adminActiveUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs actifs (30 jours)'**
  String get adminActiveUsers;

  /// No description provided for @adminDiagnostics.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostics (30 jours)'**
  String get adminDiagnostics;

  /// No description provided for @adminTrackedArea.
  ///
  /// In fr, this message translates to:
  /// **'Surface suivie'**
  String get adminTrackedArea;

  /// No description provided for @adminHectares.
  ///
  /// In fr, this message translates to:
  /// **'{value} ha'**
  String adminHectares(String value);

  /// No description provided for @adminAdoption.
  ///
  /// In fr, this message translates to:
  /// **'Adoption par région'**
  String get adminAdoption;

  /// No description provided for @adminUsersPlots.
  ///
  /// In fr, this message translates to:
  /// **'{users} utilisateurs · {plots} parcelles'**
  String adminUsersPlots(String users, String plots);

  /// No description provided for @adminMaskedRegion.
  ///
  /// In fr, this message translates to:
  /// **'Données masquées (moins de 5 utilisateurs)'**
  String get adminMaskedRegion;

  /// No description provided for @adminPrivacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection des données'**
  String get adminPrivacyTitle;

  /// No description provided for @adminPrivacyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les valeurs concernant moins de 5 cycles ou moins de 3 agriculteurs sont masquées automatiquement. Aucune donnée individuelle n\'est jamais affichée.'**
  String get adminPrivacyBody;

  /// No description provided for @adminAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès réservé à l\'administration.'**
  String get adminAccessDenied;

  /// No description provided for @adminYieldsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rendements'**
  String get adminYieldsTitle;

  /// No description provided for @adminFilterCrop.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get adminFilterCrop;

  /// No description provided for @adminFilterRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région'**
  String get adminFilterRegion;

  /// No description provided for @adminFilterSeason.
  ///
  /// In fr, this message translates to:
  /// **'Saison'**
  String get adminFilterSeason;

  /// No description provided for @adminFilterYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get adminFilterYear;

  /// No description provided for @adminFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get adminFilterAll;

  /// No description provided for @adminSeasonRainy.
  ///
  /// In fr, this message translates to:
  /// **'Saison des pluies'**
  String get adminSeasonRainy;

  /// No description provided for @adminSeasonDry.
  ///
  /// In fr, this message translates to:
  /// **'Saison sèche'**
  String get adminSeasonDry;

  /// No description provided for @adminYieldTitle.
  ///
  /// In fr, this message translates to:
  /// **'{crop} · {region}'**
  String adminYieldTitle(String crop, String region);

  /// No description provided for @adminYieldSeason.
  ///
  /// In fr, this message translates to:
  /// **'{season} {year}'**
  String adminYieldSeason(String season, String year);

  /// No description provided for @adminYieldUnit.
  ///
  /// In fr, this message translates to:
  /// **'{value} kg/ha'**
  String adminYieldUnit(String value);

  /// No description provided for @adminYieldMinMax.
  ///
  /// In fr, this message translates to:
  /// **'min {min} · max {max} kg/ha'**
  String adminYieldMinMax(String min, String max);

  /// No description provided for @adminYieldCyclesFarmers.
  ///
  /// In fr, this message translates to:
  /// **'{cycles} cycles · {farmers} agriculteurs'**
  String adminYieldCyclesFarmers(String cycles, String farmers);

  /// No description provided for @adminYieldMasked.
  ///
  /// In fr, this message translates to:
  /// **'Données masquées : échantillon trop petit pour protéger les agriculteurs'**
  String get adminYieldMasked;

  /// No description provided for @adminYieldEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour ces filtres'**
  String get adminYieldEmpty;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get registerTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get fullNameLabel;

  /// No description provided for @fullNameLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom complet doit contenir entre 2 et 120 caractères.'**
  String get fullNameLength;

  /// No description provided for @passwordLength.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir entre 8 et 128 caractères.'**
  String get passwordLength;

  /// No description provided for @registerTermsConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les conditions d\'utilisation'**
  String get registerTermsConsent;

  /// No description provided for @registerPrivacyConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte la politique de confidentialité'**
  String get registerPrivacyConsent;

  /// No description provided for @registerDataSharingConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte de partager mes données agricoles anonymisées avec l\'administration pour orienter les politiques agricoles'**
  String get registerDataSharingConsent;

  /// No description provided for @registerResearchConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'autorise l\'utilisation de mes photos pour améliorer l\'intelligence artificielle'**
  String get registerResearchConsent;

  /// No description provided for @readAction.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get readAction;

  /// No description provided for @registerSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get registerSubmit;

  /// No description provided for @registerAlreadyAccount.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get registerAlreadyAccount;

  /// No description provided for @legalTermsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get legalTermsTitle;

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get legalPrivacyTitle;

  /// No description provided for @legalProvisionalBanner.
  ///
  /// In fr, this message translates to:
  /// **'Texte provisoire : le document juridique définitif sera publié avant le lancement.'**
  String get legalProvisionalBanner;

  /// No description provided for @legalTermsParagraph1.
  ///
  /// In fr, this message translates to:
  /// **'Ces conditions décrivent les règles d\'utilisation de SmartAgri. Le document définitif précisera les droits et les obligations de chaque utilisateur.'**
  String get legalTermsParagraph1;

  /// No description provided for @legalTermsParagraph2.
  ///
  /// In fr, this message translates to:
  /// **'En utilisant l\'application, vous vous engagez à fournir des informations exactes et à respecter les usages prévus du service.'**
  String get legalTermsParagraph2;

  /// No description provided for @legalPrivacyParagraph1.
  ///
  /// In fr, this message translates to:
  /// **'Cette politique explique quelles données sont collectées et comment elles sont protégées. Le document définitif détaillera les finalités et les durées de conservation.'**
  String get legalPrivacyParagraph1;

  /// No description provided for @legalPrivacyParagraph2.
  ///
  /// In fr, this message translates to:
  /// **'Vos données personnelles ne sont jamais vendues. Vous pourrez exercer vos droits d\'accès, de rectification et de suppression auprès du support.'**
  String get legalPrivacyParagraph2;

  /// No description provided for @otpVerifyPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre numéro'**
  String get otpVerifyPhoneTitle;

  /// No description provided for @otpLoginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par SMS'**
  String get otpLoginTitle;

  /// No description provided for @otpInstructions.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code à 6 chiffres envoyé au {phone}.'**
  String otpInstructions(String phone);

  /// No description provided for @otpValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get otpValidate;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @loginVerifyPhone.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier mon numéro'**
  String get loginVerifyPhone;

  /// No description provided for @loginReceiveSmsCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un code par SMS'**
  String get loginReceiveSmsCode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['dje', 'fr', 'ha'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'dje':
      return AppLocalizationsDje();
    case 'fr':
      return AppLocalizationsFr();
    case 'ha':
      return AppLocalizationsHa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
