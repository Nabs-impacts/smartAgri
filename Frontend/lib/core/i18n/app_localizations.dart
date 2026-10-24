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
