import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_localizations.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/auth/domain/auth_error_messages.dart';

void main() {
  final AppLocalizations strings = lookupAppLocalizations(const Locale('fr'));

  String message(String code, String content, {int? statusCode}) {
    return authErrorMessage(
      ApiException(code: code, message: content, statusCode: statusCode),
      strings,
    );
  }

  test('invalid credentials', () {
    expect(
      message('UNAUTHORIZED', 'Identifiants incorrects.'),
      strings.authErrorInvalidCredentials,
    );
  });

  test('phone not verified', () {
    expect(
      message('UNAUTHORIZED', 'Numéro de téléphone non vérifié.'),
      strings.authErrorPhoneNotVerified,
    );
    expect(
      message('FORBIDDEN', 'Téléphone non vérifié.'),
      strings.authErrorPhoneNotVerified,
    );
  });

  test('invalid or expired otp', () {
    expect(
      message('UNAUTHORIZED', 'Code invalide ou expiré.'),
      strings.authErrorOtpInvalid,
    );
  });

  test('rate limited', () {
    expect(
      message('RATE_LIMITED', 'Trop de tentatives.'),
      strings.authErrorRateLimited,
    );
    expect(
      message('UNAUTHORIZED', 'Trop de requêtes.', statusCode: 429),
      strings.authErrorRateLimited,
    );
  });

  test('phone already used', () {
    expect(
      message('CONFLICT', 'Ce numéro est déjà enregistré.'),
      strings.authErrorPhoneAlreadyUsed,
    );
  });

  test('account disabled', () {
    expect(
      message('FORBIDDEN', 'Compte utilisateur désactivé.'),
      strings.authErrorAccountDisabled,
    );
  });

  test('network and timeout errors', () {
    expect(
      message(ApiException.networkErrorCode, ''),
      strings.authErrorNetwork,
    );
    expect(message(ApiException.timeoutCode, ''), strings.authErrorTimeout);
  });

  test('invalid phone and generic errors', () {
    expect(message('INVALID_PHONE', ''), strings.authErrorInvalidPhone);
    expect(message('INTERNAL_ERROR', ''), strings.authErrorGeneric);
  });
}
