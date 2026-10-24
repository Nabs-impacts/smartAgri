import '../i18n/app_localizations.dart';
import 'api_exception.dart';

String apiErrorMessage(ApiException exception, AppLocalizations strings) {
  if (exception.isQuotaExceeded) {
    final int? limit = _detailLimit(exception.details);
    if (limit != null) {
      return strings.errorQuotaExceeded('$limit');
    }
    return strings.errorGeneric;
  }
  if (exception.code == ApiException.networkErrorCode) {
    return strings.errorNetwork;
  }
  if (exception.isTimeout) {
    return strings.errorTimeout;
  }
  if (exception.statusCode == 404 || exception.code == 'NOT_FOUND') {
    return strings.errorNotFound;
  }
  if (exception.statusCode == 409 || exception.code == 'CONFLICT') {
    return strings.errorConflict;
  }
  return strings.errorGeneric;
}

int? _detailLimit(Object? details) {
  if (details is Map) {
    final Object? limit = details['limit'];
    if (limit is num) {
      return limit.toInt();
    }
    if (limit is String) {
      return int.tryParse(limit);
    }
  }
  return null;
}
