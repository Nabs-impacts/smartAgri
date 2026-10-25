import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/catalog/data/catalog_repository.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_flow_controller.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_new_page.dart';
import 'package:smartagri/features/farms/data/farms_providers.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../app_test_utils.dart';
import '../media/media_test_utils.dart';
import 'diagnostic_test_utils.dart';

class FixedMeController extends MeController {
  FixedMeController(this.data);

  final MeData? data;

  @override
  Future<MeData?> build() async => data;

  @override
  Future<void> refresh() async {}
}

class FixedCropsController extends CropsController {
  FixedCropsController(this.crops);

  final List<Crop> crops;

  @override
  Future<List<Crop>> build() async => crops;
}

class FixedFarmsController extends FarmsController {
  @override
  Future<List<Farm>> build() async => const <Farm>[];
}

class FakeFlowController extends DiagnosticFlowController {
  FakeFlowController(this.initial);

  final DiagnosticFlowState initial;
  int submitCalls = 0;
  int cancelCalls = 0;
  final List<String?> selectedCrops = <String?>[];
  final List<String> removedPhotos = <String>[];

  @override
  DiagnosticFlowState build() => initial;

  @override
  void selectCrop(int? cropId) {
    state = state.copyWith(cropId: cropId);
  }

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    state = state.copyWith(
      photos: <FlowPhoto>[
        ...state.photos,
        FlowPhoto(
          mediaId: 'media-1',
          image: sampleCompressedImage(),
          status: FlowPhotoStatus.ready,
        ),
      ],
    );
  }

  @override
  void removePhoto(String mediaId) {
    removedPhotos.add(mediaId);
    state = state.copyWith(
      photos: state.photos
          .where((FlowPhoto photo) => photo.mediaId != mediaId)
          .toList(),
    );
  }

  @override
  Future<void> submit() async {
    submitCalls++;
    state = state.copyWith(
      submitting: false,
      created: sampleDiagnostic(id: 'diag-1'),
    );
  }

  @override
  void cancelUploads() {
    cancelCalls++;
    state = state.copyWith(submitting: false);
  }
}

DiagnosticFlowState flowState({
  List<FlowPhoto> photos = const <FlowPhoto>[],
  int? cropId,
  String? plotId,
  bool submitting = false,
  bool quotaExceeded = false,
}) {
  return DiagnosticFlowState(
    diagnosticId: 'diag-1',
    idempotencyKey: 'idem-1',
    photos: photos,
    cropId: cropId,
    plotId: plotId,
    submitting: submitting,
    quotaExceeded: quotaExceeded,
  );
}

GoRouter buildNewRouter() {
  return GoRouter(
    initialLocation: '/diagnostic/new',
    routes: <RouteBase>[
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const DiagnosticNewPage(),
      ),
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text('route résultat ${state.pathParameters['diagnosticId']}'),
        ),
      ),
    ],
  );
}

Future<ProviderContainer> pumpNewPage(
  WidgetTester tester, {
  DiagnosticFlowState? state,
  MeData? me,
  DiagnosticPhotoPicker? picker,
  FakeFlowController? controller,
  bool settle = true,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final FakeFlowController flow =
      controller ?? FakeFlowController(state ?? flowState());
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      meProvider.overrideWith(() => FixedMeController(me ?? sampleMeData())),
      cropsProvider.overrideWith(
        () => FixedCropsController(const <Crop>[
          Crop(id: 3, code: 'MILLET', nameFr: 'Mil', category: 'cereal'),
        ]),
      ),
      farmsProvider.overrideWith(FixedFarmsController.new),
      diagnosticFlowProvider.overrideWith(() => flow),
      diagnosticPhotoPickerProvider.overrideWithValue(
        picker ??
            ({required bool camera}) async => sampleCompressedImage().bytes,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router ?? buildNewRouter(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return container;
}

void main() {
  testWidgets('renders the tips, the fields and a disabled analyze button', (
    WidgetTester tester,
  ) async {
    await pumpNewPage(tester);

    expect(find.text('Nouveau diagnostic'), findsOneWidget);
    expect(find.text('Conseils pour une bonne photo'), findsOneWidget);
    expect(find.text('Culture (facultatif)'), findsOneWidget);
    expect(find.text('Parcelle (facultatif)'), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_crop_field')), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_plot_field')), findsOneWidget);
    expect(find.byKey(const Key('photo_tile_add')), findsOneWidget);

    final AppButton analyze = tester.widget<AppButton>(
      find.byKey(const Key('diagnostic_analyze')),
    );
    expect(analyze.onPressed, isNull);
  });

  testWidgets('picks a photo, shows it and enables the analysis', (
    WidgetTester tester,
  ) async {
    await pumpNewPage(tester);

    await tester.tap(find.byKey(const Key('diagnostic_choose_gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostic_photo_media-1')), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_photo_uploaded')), findsNothing);
    final AppButton analyze = tester.widget<AppButton>(
      find.byKey(const Key('diagnostic_analyze')),
    );
    expect(analyze.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('photo_tile_delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic_photo_media-1')), findsNothing);
  });

  testWidgets('shows the picker error when the picker throws', (
    WidgetTester tester,
  ) async {
    await pumpNewPage(
      tester,
      picker: ({required bool camera}) async => throw Exception('refus'),
    );

    await tester.tap(find.byKey(const Key('diagnostic_take_photo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostic_photo_error')), findsOneWidget);
    expect(find.text('Impossible de traiter cette photo.'), findsOneWidget);
  });

  testWidgets('shows the quota banner and disables the analysis', (
    WidgetTester tester,
  ) async {
    await pumpNewPage(
      tester,
      me: sampleMeData(
        quotas: const <Quota>[
          Quota(
            metric: 'diagnostics_per_month',
            limit: 10,
            used: 10,
            remaining: 0,
          ),
        ],
      ),
    );

    expect(find.byKey(const Key('diagnostic_quota_banner')), findsOneWidget);
    expect(
      find.text('Vous avez atteint la limite de diagnostics de ce mois'),
      findsOneWidget,
    );
    final AppButton analyze = tester.widget<AppButton>(
      find.byKey(const Key('diagnostic_analyze')),
    );
    expect(analyze.onPressed, isNull);
  });

  testWidgets('submits and navigates to the created result', (
    WidgetTester tester,
  ) async {
    final FakeFlowController flow = FakeFlowController(
      flowState(
        photos: <FlowPhoto>[
          FlowPhoto(
            mediaId: 'media-1',
            image: sampleCompressedImage(),
            status: FlowPhotoStatus.ready,
          ),
        ],
      ),
    );
    await pumpNewPage(tester, controller: flow);

    await tester.tap(find.byKey(const Key('diagnostic_analyze')));
    await tester.pumpAndSettle();

    expect(flow.submitCalls, 1);
    expect(find.text('route résultat diag-1'), findsOneWidget);
  });

  testWidgets('shows the upload progress while submitting', (
    WidgetTester tester,
  ) async {
    await pumpNewPage(
      tester,
      state: flowState(
        photos: <FlowPhoto>[
          FlowPhoto(
            mediaId: 'media-1',
            image: sampleCompressedImage(),
            status: FlowPhotoStatus.uploading,
            progress: 0.5,
          ),
        ],
        submitting: true,
      ),
      settle: false,
    );

    final AppProgressBar progress = tester.widget<AppProgressBar>(
      find.byKey(const Key('diagnostic_global_progress')),
    );
    expect(progress.value, 0.5);
    expect(find.byKey(const Key('photo_tile_add')), findsNothing);
  });

  testWidgets('confirms before leaving during an upload', (
    WidgetTester tester,
  ) async {
    final FakeFlowController flow = FakeFlowController(
      flowState(
        photos: <FlowPhoto>[
          FlowPhoto(
            mediaId: 'media-1',
            image: sampleCompressedImage(),
            status: FlowPhotoStatus.uploading,
            progress: 0.4,
          ),
        ],
        submitting: true,
      ),
    );
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('route accueil')),
        ),
        GoRoute(
          path: '/diagnostic/new',
          builder: (_, _) => const DiagnosticNewPage(),
        ),
      ],
    );
    await pumpNewPage(tester, controller: flow, settle: false, router: router);
    router.push('/diagnostic/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).last,
    );
    navigator.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Quitter l'envoi ?"), findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnostic_exit_confirm')));
    await tester.pumpAndSettle();

    expect(flow.cancelCalls, 1);
  });
}
