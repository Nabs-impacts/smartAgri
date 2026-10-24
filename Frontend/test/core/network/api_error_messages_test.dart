import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_localizations.dart';
import 'package:smartagri/core/network/api_error_messages.dart';
import 'package:smartagri/core/network/api_exception.dart';

void main() {
  final AppLocalizations strings = lookupAppLocalizations(const Locale('fr'));

  test('maps network, timeout, not found and conflict errors', () {
    expect(
      apiErrorMessage(ApiException.network(), strings),
      strings.errorNetwork,
    );
    expect(
      apiErrorMessage(
        const ApiException(code: 'TIMEOUT', message: ''),
        strings,
      ),
      strings.errorTimeout,
    );
    expect(
      apiErrorMessage(
        const ApiException(statusCode: 404, code: 'NOT_FOUND', message: ''),
        strings,
      ),
      strings.errorNotFound,
    );
    expect(
      apiErrorMessage(
        const ApiException(statusCode: 409, code: 'CONFLICT', message: ''),
        strings,
      ),
      strings.errorConflict,
    );
  });

  test('shows the plan limit for a quota error', () {
    final String message = apiErrorMessage(
      const ApiException(
        statusCode: 403,
        code: 'QUOTA_EXCEEDED',
        message: 'Quota dépassé',
        details: <String, dynamic>{'metric': 'plots', 'limit': 5, 'used': 5},
      ),
      strings,
    );

    expect(
      message,
      'Vous avez atteint la limite de votre formule (5 parcelles).',
    );
  });

  test('falls back to the generic message', () {
    expect(
      apiErrorMessage(
        const ApiException(code: 'UNKNOWN_ERROR', message: ''),
        strings,
      ),
      strings.errorGeneric,
    );
  });
}
