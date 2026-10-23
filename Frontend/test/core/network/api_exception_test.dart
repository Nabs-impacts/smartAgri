import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';

void main() {
  test('parses the standard error body', () {
    final ApiException exception = ApiException.fromResponse(
      403,
      <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'QUOTA_EXCEEDED',
          'message': 'Quota dépassé.',
          'details': <String, dynamic>{'limit': 10},
        },
      },
    );

    expect(exception.statusCode, 403);
    expect(exception.code, 'QUOTA_EXCEEDED');
    expect(exception.message, 'Quota dépassé.');
    expect(exception.details, <String, dynamic>{'limit': 10});
    expect(exception.isQuotaExceeded, isTrue);
    expect(exception.isUnauthorized, isFalse);
    expect(exception.isNetwork, isFalse);
  });

  test('parses a JSON string body', () {
    final ApiException exception = ApiException.fromResponse(
      401,
      '{"error":{"code":"UNAUTHORIZED","message":"Session invalide.","details":null}}',
    );

    expect(exception.code, 'UNAUTHORIZED');
    expect(exception.message, 'Session invalide.');
    expect(exception.isUnauthorized, isTrue);
  });

  test('falls back to a generic French message', () {
    final ApiException exception = ApiException.fromResponse(
      500,
      <String, dynamic>{'unexpected': true},
    );

    expect(exception.code, ApiException.unknownErrorCode);
    expect(exception.message, ApiException.genericMessage);
    expect(exception.statusCode, 500);
  });

  test('maps connection errors to NETWORK_ERROR', () {
    final ApiException exception = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/items'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(exception.code, ApiException.networkErrorCode);
    expect(exception.isNetwork, isTrue);
    expect(exception.isTimeout, isFalse);
  });

  test('maps timeouts to TIMEOUT', () {
    final ApiException exception = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/items'),
        type: DioExceptionType.receiveTimeout,
      ),
    );

    expect(exception.code, ApiException.timeoutCode);
    expect(exception.isNetwork, isTrue);
    expect(exception.isTimeout, isTrue);
  });

  test('maps bad responses through the standard parser', () {
    final ApiException exception = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/items'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/items'),
          statusCode: 403,
          data: <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'QUOTA_EXCEEDED',
              'message': 'Quota dépassé.',
              'details': null,
            },
          },
        ),
      ),
    );

    expect(exception.isQuotaExceeded, isTrue);
    expect(exception.statusCode, 403);
  });
}
