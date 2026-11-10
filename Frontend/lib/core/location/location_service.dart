import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus { granted, denied, deniedForever, unsupported }

enum LocationAvailability { enabled, disabled, unsupported }

enum LocationOutcomeStatus {
  success,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unsupported,
  timeout,
  error,
}

class LocationPosition {
  const LocationPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class LocationResult {
  const LocationResult._(this.status, this.position);

  const LocationResult.success(LocationPosition position)
    : this._(LocationOutcomeStatus.success, position);

  const LocationResult.failure(LocationOutcomeStatus status)
    : this._(status, null);

  final LocationOutcomeStatus status;
  final LocationPosition? position;

  bool get isSuccess => status == LocationOutcomeStatus.success;
}

abstract interface class LocationService {
  Future<LocationPermissionStatus> requestPermission();

  Future<LocationAvailability> checkService();

  Future<LocationResult> currentPosition();

  Future<bool> openAppSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const Duration _timeout = Duration(seconds: 15);

  bool get _supported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  LocationPermissionStatus _permission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    if (!_supported) {
      return LocationPermissionStatus.unsupported;
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _permission(permission);
    } catch (_) {
      return LocationPermissionStatus.unsupported;
    }
  }

  @override
  Future<LocationAvailability> checkService() async {
    if (!_supported) {
      return LocationAvailability.unsupported;
    }
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      return enabled
          ? LocationAvailability.enabled
          : LocationAvailability.disabled;
    } catch (_) {
      return LocationAvailability.unsupported;
    }
  }

  @override
  Future<LocationResult> currentPosition() async {
    if (!_supported) {
      return const LocationResult.failure(LocationOutcomeStatus.unsupported);
    }
    final LocationAvailability availability = await checkService();
    if (availability == LocationAvailability.unsupported) {
      return const LocationResult.failure(LocationOutcomeStatus.unsupported);
    }
    if (availability == LocationAvailability.disabled) {
      return const LocationResult.failure(
        LocationOutcomeStatus.serviceDisabled,
      );
    }
    final LocationPermissionStatus permission = await requestPermission();
    switch (permission) {
      case LocationPermissionStatus.unsupported:
        return const LocationResult.failure(LocationOutcomeStatus.unsupported);
      case LocationPermissionStatus.denied:
        return const LocationResult.failure(
          LocationOutcomeStatus.permissionDenied,
        );
      case LocationPermissionStatus.deniedForever:
        return const LocationResult.failure(
          LocationOutcomeStatus.permissionDeniedForever,
        );
      case LocationPermissionStatus.granted:
        break;
    }
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      ).timeout(_timeout);
      return LocationResult.success(
        LocationPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );
    } on TimeoutException {
      return const LocationResult.failure(LocationOutcomeStatus.timeout);
    } on PermissionDeniedException {
      final LocationPermissionStatus current = await requestPermission();
      if (current == LocationPermissionStatus.deniedForever) {
        return const LocationResult.failure(
          LocationOutcomeStatus.permissionDeniedForever,
        );
      }
      return const LocationResult.failure(
        LocationOutcomeStatus.permissionDenied,
      );
    } catch (_) {
      return const LocationResult.failure(LocationOutcomeStatus.error);
    }
  }

  @override
  Future<bool> openAppSettings() async {
    if (!_supported) {
      return false;
    }
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) {
      return const GeolocatorLocationService();
    });
