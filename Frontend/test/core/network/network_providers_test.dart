import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/config/app_config.dart';
import 'package:smartagri/core/network/network_providers.dart';

void main() {
  test('storage client has no interceptor', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Dio storage = container.read(storageClientProvider);

    expect(storage.interceptors, isEmpty);
    expect(storage.options.baseUrl, isEmpty);
    expect(storage.options.connectTimeout, const Duration(seconds: 15));
    expect(storage.options.receiveTimeout, const Duration(seconds: 30));
    expect(storage.options.sendTimeout, const Duration(seconds: 60));
  });

  test('refresh client has no interceptor', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Dio refresh = container.read(refreshDioProvider);

    expect(refresh.interceptors, isEmpty);
    expect(refresh.options.baseUrl, AppConfig.apiBaseUrl);
  });

  test('api client is configured with authentication and errors', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Dio api = container.read(apiClientProvider);

    expect(api.options.baseUrl, AppConfig.apiBaseUrl);
    expect(api.options.connectTimeout, const Duration(seconds: 15));
    expect(api.options.receiveTimeout, const Duration(seconds: 30));
    expect(api.interceptors, hasLength(2));
  });
}
