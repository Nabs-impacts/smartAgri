import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

class AppLocalizationsHa extends AppLocalizations {
  AppLocalizationsHa([String locale = 'ha']) : super(locale);

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
}
