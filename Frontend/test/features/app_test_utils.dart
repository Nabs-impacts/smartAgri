import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/auth/data/auth_repository.dart';
import 'package:smartagri/features/admin/data/stats_repository.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/catalog/data/catalog_repository.dart';
import 'package:smartagri/features/catalog/domain/admin_area.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import 'diagnostics/fake_diagnostics_repository.dart';
import 'farms/fake_farms_repository.dart';

class FixedSessionController extends SessionController {
  FixedSessionController(this.fixedState);

  final SessionState fixedState;

  @override
  SessionState build() => fixedState;
}

class FixedStaleController extends MeStaleController {
  FixedStaleController(this.initial);

  final bool initial;

  @override
  bool build() => initial;
}

class FixedAdminAreasController extends AdminAreasController {
  FixedAdminAreasController(this.areas);

  final List<AdminArea> areas;

  @override
  Future<List<AdminArea>> build() async => areas;
}

const List<AdminArea> sampleAdminAreas = <AdminArea>[
  AdminArea(id: 1, level: 'region', name: 'Niamey', code: 'NER-NIAMEY'),
  AdminArea(id: 2, level: 'region', name: 'Dosso', code: 'NER-DOSSO'),
];

class FixedCropsController extends CropsController {
  FixedCropsController(this.crops);

  final List<Crop> crops;

  @override
  Future<List<Crop>> build() async => crops;
}

const List<Crop> sampleCrops = <Crop>[
  Crop(
    id: 1,
    code: 'MIL',
    nameFr: 'Mil',
    nameHa: 'Gero',
    nameDje: 'Haini',
    category: 'cereal',
  ),
  Crop(
    id: 2,
    code: 'SOR',
    nameFr: 'Sorgho',
    nameHa: 'Dawa',
    nameDje: 'Dawa',
    category: 'cereal',
  ),
];

class FakeMeRepository extends MeRepository {
  FakeMeRepository(this.data) : super(dio: Dio());

  MeData data;
  ApiException? error;
  Completer<MeData>? completer;
  int getMeCalls = 0;
  int updateLanguageCalls = 0;
  final List<AppLanguage> languages = <AppLanguage>[];

  @override
  Future<MeData> getMe() async {
    getMeCalls++;
    if (completer != null) {
      return completer!.future;
    }
    if (error != null) {
      throw error!;
    }
    return data;
  }

  @override
  Future<void> updateLanguage(AppLanguage language) async {
    updateLanguageCalls++;
    languages.add(language);
    if (error != null) {
      throw error!;
    }
  }
}

class RecordingAuthRepository extends AuthRepository {
  RecordingAuthRepository()
    : super(
        dio: Dio(),
        tokenStore: TokenStore(storage: _MemoryTokenStorage()),
        onSignedOut: () async {},
      );

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _MemoryTokenStorage implements TokenStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

MeData sampleMeData({
  String fullName = 'Amina Diallo',
  String phone = '+22790203040',
  String role = 'farmer',
  List<Quota>? quotas,
}) {
  return MeData(
    user: UserProfile(
      id: 'user-id',
      phone: phone,
      fullName: fullName,
      role: role,
      language: 'fr',
    ),
    quotas:
        quotas ??
        const <Quota>[
          Quota(
            metric: 'diagnostics_per_month',
            limit: 10,
            used: 3,
            remaining: 7,
          ),
        ],
    plan: const MePlan(
      code: 'free',
      name: 'Gratuit',
      audience: 'farmer',
      billingModel: 'freemium',
    ),
  );
}

Future<ProviderContainer> buildTestContainer({
  required MeRepository meRepository,
  SessionState session = SessionState.authenticated,
  AuthRepository? authRepository,
  bool stale = false,
  Map<String, Object> initialPreferences = const <String, Object>{},
  List<AdminArea> adminAreas = sampleAdminAreas,
  List<Crop>? crops,
  StatsRepository? statsRepository,
  FarmsRepository? farmsRepository,
  DiagnosticsRepository? diagnosticsRepository,
  SessionController? sessionController,
}) async {
  await initializeDateFormatting('fr');
  SharedPreferences.setMockInitialValues(initialPreferences);
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sessionControllerProvider.overrideWith(
        () => sessionController ?? FixedSessionController(session),
      ),
      meRepositoryProvider.overrideWithValue(meRepository),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? RecordingAuthRepository(),
      ),
      farmsRepositoryProvider.overrideWithValue(
        farmsRepository ?? FakeFarmsRepository(),
      ),
      diagnosticsRepositoryProvider.overrideWithValue(
        diagnosticsRepository ?? FakeDiagnosticsRepository(),
      ),
      adminAreasProvider.overrideWith(
        () => FixedAdminAreasController(adminAreas),
      ),
      if (crops != null)
        cropsProvider.overrideWith(() => FixedCropsController(crops)),
      if (statsRepository != null)
        statsRepositoryProvider.overrideWithValue(statsRepository),
      if (stale) meStaleProvider.overrideWith(() => FixedStaleController(true)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget testApp(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

Widget testRouterApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}
