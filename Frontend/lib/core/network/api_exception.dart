import 'dart:convert';

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  static const String networkErrorCode = 'NETWORK_ERROR';
  static const String timeoutCode = 'TIMEOUT';
  static const String unknownErrorCode = 'UNKNOWN_ERROR';
  static const String genericMessage =
      'Une erreur est survenue. Veuillez réessayer.';

  final int? statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isQuotaExceeded => code == 'QUOTA_EXCEEDED';

  bool get isUnauthorized => statusCode == 401 || code == 'UNAUTHORIZED';

  bool get isNetwork => code == networkErrorCode || code == timeoutCode;

  bool get isTimeout => code == timeoutCode;

  factory ApiException.fromResponse(int? statusCode, Object? data) {
    final Map<String, dynamic>? body = _asMap(data);
    final Object? rawError = body?['error'];
    final Map<String, dynamic>? error = _asMap(rawError);
    final Object? code = error?['code'];
    final Object? message = error?['message'];
    if (code is String && message is String) {
      return ApiException(
        statusCode: statusCode,
        code: code,
        message: message,
        details: error?['details'],
      );
    }
    return ApiException(
      statusCode: statusCode,
      code: unknownErrorCode,
      message: genericMessage,
    );
  }

  factory ApiException.network() {
    return const ApiException(
      code: networkErrorCode,
      message: 'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
    );
  }

  factory ApiException.timeout() {
    return const ApiException(
      code: timeoutCode,
      message: 'Le serveur met trop de temps à répondre. Réessayez.',
    );
  }

  factory ApiException.fromDioException(DioException exception) {
    final Object? error = exception.error;
    if (error is ApiException) {
      return error;
    }
    switch (exception.type) {
      case DioExceptionType.connectionError:
        return ApiException.network();
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException.timeout();
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(
          exception.response?.statusCode,
          exception.response?.data,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiException(
          code: unknownErrorCode,
          message: genericMessage,
        );
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (Object? key, Object? item) =>
            MapEntry<String, dynamic>(key.toString(), item),
      );
    }
    if (value is String) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map(
            (Object? key, Object? item) =>
                MapEntry<String, dynamic>(key.toString(), item),
          );
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
