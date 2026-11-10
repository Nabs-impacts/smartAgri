import '../i18n/app_localizations.dart';
import 'location_service.dart';

String? locationErrorMessage(
  AppLocalizations strings,
  LocationOutcomeStatus status,
) {
  switch (status) {
    case LocationOutcomeStatus.success:
      return null;
    case LocationOutcomeStatus.permissionDenied:
      return strings.locationDenied;
    case LocationOutcomeStatus.permissionDeniedForever:
      return strings.locationDeniedForever;
    case LocationOutcomeStatus.serviceDisabled:
      return strings.locationServiceDisabled;
    case LocationOutcomeStatus.unsupported:
      return strings.locationUnsupported;
    case LocationOutcomeStatus.timeout:
      return strings.locationTimeout;
    case LocationOutcomeStatus.error:
      return strings.locationError;
  }
}
