import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../../core/network/fake_http_adapter.dart';

Map<String, dynamic> meBody() {
  return <String, dynamic>{
    'user': <String, dynamic>{
      'id': '0d9f9d3e-0b38-4a1f-8a2f-1f57f6f0c001',
      'phone': '+22790203040',
      'email': 'amina@example.com',
      'full_name': 'Amina Diallo',
      'role': 'farmer',
      'language': 'fr',
      'admin_area_id': 3,
      'is_active': true,
      'phone_verified_at': '2026-10-01T10:00:00Z',
      'created_at': '2026-10-01T09:00:00Z',
    },
    'effective_plan': <String, dynamic>{
      'code': 'free',
      'name': 'Gratuit',
      'audience': 'farmer',
      'billing_model': 'freemium',
      'quotas': <String, dynamic>{'plots': 3, 'diagnostics_per_month': 10},
      'features': <String, dynamic>{'diagnostic': true},
    },
    'quotas': <Map<String, dynamic>>[
      <String, dynamic>{
        'metric': 'plots',
        'limit': 3,
        'used': 2,
        'remaining': 1,
      },
      <String, dynamic>{
        'metric': 'diagnostics_per_month',
        'limit': 10,
        'used': 0,
        'remaining': 10,
      },
      <String, dynamic>{
        'metric': 'video_analyses_per_month',
        'limit': -1,
        'used': 0,
        'remaining': 0,
      },
    ],
  };
}

void main() {
  test('getMe calls the endpoint and parses the profile and quotas', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, meBody()),
    );
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    final MeRepository repository = MeRepository(dio: dio);

    final MeData data = await repository.getMe();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/users/me');
    expect(data.user.fullName, 'Amina Diallo');
    expect(data.user.phone, '+22790203040');
    expect(data.plan?.code, 'free');
    expect(data.plan?.name, 'Gratuit');
    expect(data.quotas, hasLength(3));
    expect(data.quotas[0].metric, 'plots');
    expect(data.quotas[0].limit, 3);
    expect(data.quotas[0].used, 2);
    expect(data.quotas[0].remaining, 1);
    expect(data.quotas[2].isUnlimited, isTrue);
  });

  test('updateLanguage patches the exact body', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, <String, dynamic>{}),
    );
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    final MeRepository repository = MeRepository(dio: dio);

    await repository.updateLanguage(AppLanguage.ha);

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/users/me');
    expect(adapter.requests.single.data, <String, dynamic>{'language': 'ha'});
  });

  test('missing fields fall back to safe values', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'id',
          'phone': '+22790203040',
          'full_name': 'Amina Diallo',
          'role': 'farmer',
        },
        'quotas': <Map<String, dynamic>>[
          <String, dynamic>{'metric': 'plots', 'used': 1},
        ],
      }),
    );
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    final MeRepository repository = MeRepository(dio: dio);

    final MeData data = await repository.getMe();

    expect(data.plan, isNull);
    expect(data.quotas.single.limit, -1);
    expect(data.quotas.single.isUnlimited, isTrue);
  });
}
