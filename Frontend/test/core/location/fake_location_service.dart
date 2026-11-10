import 'package:smartagri/core/location/location_service.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.result = const LocationResult.failure(LocationOutcomeStatus.error),
    this.permission = LocationPermissionStatus.granted,
    this.availability = LocationAvailability.enabled,
    this.settingsOpened = true,
    List<LocationResult>? results,
  }) : results = results ?? <LocationResult>[];

  LocationResult result;
  final List<LocationResult> results;
  LocationPermissionStatus permission;
  LocationAvailability availability;
  bool settingsOpened;
  int permissionCalls = 0;
  int positionCalls = 0;
  int settingsCalls = 0;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    permissionCalls++;
    return permission;
  }

  @override
  Future<LocationAvailability> checkService() async => availability;

  @override
  Future<LocationResult> currentPosition() async {
    positionCalls++;
    if (results.isNotEmpty) {
      return results.removeAt(0);
    }
    return result;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return settingsOpened;
  }
}
