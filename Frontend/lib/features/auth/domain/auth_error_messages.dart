import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_exception.dart';

bool isPhoneNotVerifiedError(ApiException exception) {
  if (exception.code != 'UNAUTHORIZED' && exception.code != 'FORBIDDEN') {
    return false;
  }
  return exception.message.toLowerCase().contains('vérifi');
}

bool isInvalidCodeError(ApiException exception) {
  final String message = exception.message.toLowerCase();
  return message.contains('code') &&
      (message.contains('invalide') || message.contains('expir'));
}

String authErrorMessage(ApiException exception, AppLocalizations strings) {
  final String code = exception.code;
  if (code == 'INVALID_PHONE') {
    return strings.authErrorInvalidPhone;
  }
  if (code == ApiException.networkErrorCode) {
    return strings.authErrorNetwork;
  }
  if (code == ApiException.timeoutCode) {
    return strings.authErrorTimeout;
  }
  if (code == 'RATE_LIMITED' || exception.statusCode == 429) {
    return strings.authErrorRateLimited;
  }
  if (code == 'CONFLICT' || exception.statusCode == 409) {
    return strings.authErrorPhoneAlreadyUsed;
  }
  if (code == 'UNAUTHORIZED') {
    final String message = exception.message.toLowerCase();
    if (message.contains('code invalide')) {
      return strings.authErrorOtpInvalid;
    }
    if (message.contains('vérifi')) {
      return strings.authErrorPhoneNotVerified;
    }
    return strings.authErrorInvalidCredentials;
  }
  if (code == 'FORBIDDEN') {
    final String message = exception.message.toLowerCase();
    if (message.contains('désactiv')) {
      return strings.authErrorAccountDisabled;
    }
    if (message.contains('vérifi')) {
      return strings.authErrorPhoneNotVerified;
    }
    return strings.authErrorGeneric;
  }
  return strings.authErrorGeneric;
}
