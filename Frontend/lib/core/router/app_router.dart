import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_overview_page.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/admin_yields_page.dart';
import '../../features/auth/domain/otp_args.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/common/placeholder_page.dart';
import '../../features/cycles/presentation/activity_form_page.dart';
import '../../features/cycles/presentation/cycle_detail_page.dart';
import '../../features/cycles/presentation/cycle_form_page.dart';
import '../../features/cycles/presentation/harvest_form_page.dart';
import '../../features/cycles/presentation/plot_timeline_page.dart';
import '../../features/dev_gallery/design_gallery_page.dart';
import '../../features/diagnostics/presentation/diagnostic_new_page.dart';
import '../../features/diagnostics/presentation/diagnostics_history_page.dart';
import '../../features/diagnostics/presentation/diagnostic_result_page.dart';
import '../../features/farms/domain/plot_geometry.dart';
import '../../features/farms/presentation/farm_detail_page.dart';
import '../../features/farms/presentation/farm_form_page.dart';
import '../../features/farms/presentation/farms_page.dart';
import '../../features/farms/presentation/plot_boundary_editor_page.dart';
import '../../features/farms/presentation/plot_detail_page.dart';
import '../../features/farms/presentation/plot_form_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/legal/legal_page.dart';
import '../../features/privacy/presentation/consents_page.dart';
import '../../features/privacy/presentation/delete_account_page.dart';
import '../../features/profile/data/me_repository.dart';
import '../../features/profile/profile_page.dart';
import '../../features/search/search_page.dart';
import '../../features/sync/presentation/sync_failed_page.dart';
import '../config/app_config.dart';
import 'app_page.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';

final Provider<String> startRouteProvider = Provider<String>(
  (Ref ref) => AppConfig.startRoute,
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  bool disposed = false;
  void scheduleRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!disposed) {
        refresh.value++;
      }
    });
  }

  ref.listen<SessionState>(
    sessionControllerProvider,
    (_, _) => scheduleRefresh(),
  );
  ref.listen<AsyncValue<MeData?>>(meProvider, (_, AsyncValue<MeData?> next) {
    if (next.isLoading && !next.hasValue) {
      return;
    }
    scheduleRefresh();
  });
  ref.onDispose(() {
    disposed = true;
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: kDebugMode ? ref.read(startRouteProvider) : '/splash',
    refreshListenable: refresh,
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) =>
            AppPage(child: const PlaceholderPage(title: 'Chargement')),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) => AppPage(child: const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, _) => AppPage(child: const RegisterPage()),
      ),
      GoRoute(
        path: '/otp',
        redirect: (_, GoRouterState state) =>
            state.extra is OtpArgs ? null : '/login',
        pageBuilder: (_, GoRouterState state) =>
            AppPage(child: OtpPage(args: state.extra! as OtpArgs)),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, _) => AppPage(child: const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/legal/terms',
        pageBuilder: (_, _) =>
            AppPage(child: const LegalPage(document: LegalDocument.terms)),
      ),
      GoRoute(
        path: '/legal/privacy',
        pageBuilder: (_, _) =>
            AppPage(child: const LegalPage(document: LegalDocument.privacy)),
      ),
      GoRoute(
        path: '/privacy/consents',
        pageBuilder: (_, _) => AppPage(child: const ConsentsPage()),
      ),
      GoRoute(
        path: '/privacy/delete',
        pageBuilder: (_, _) => AppPage(child: const DeleteAccountPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => HomeShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const SearchPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AdminShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/overview',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const AdminOverviewPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/yields',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const AdminYieldsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/profile',
                pageBuilder: (_, _) => AppPage(
                  transition: AppPageTransition.fade,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/admin', redirect: (_, _) => '/admin/overview'),
      GoRoute(
        path: '/farms',
        pageBuilder: (_, _) => AppPage(child: const FarmsPage()),
      ),
      GoRoute(
        path: '/farms/new',
        pageBuilder: (_, _) => AppPage(
          transition: AppPageTransition.vertical,
          child: const FarmFormPage(),
        ),
      ),
      GoRoute(
        path: '/farms/:farmId/edit',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: FarmFormPage(farmId: state.pathParameters['farmId']),
        ),
      ),
      GoRoute(
        path: '/farms/:farmId/plots/new',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: PlotFormPage(farmId: state.pathParameters['farmId']),
        ),
      ),
      GoRoute(
        path: '/farms/:farmId',
        pageBuilder: (_, GoRouterState state) => AppPage(
          child: FarmDetailPage(farmId: state.pathParameters['farmId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/plots/boundary',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: PlotBoundaryEditorPage(
            initialGeometry: state.extra is PlotGeometry
                ? state.extra! as PlotGeometry
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/plots/:plotId/edit',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: PlotFormPage(plotId: state.pathParameters['plotId']),
        ),
      ),
      GoRoute(
        path: '/plots/:plotId/cycles/new',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: CycleFormPage(plotId: state.pathParameters['plotId']),
        ),
      ),
      GoRoute(
        path: '/plots/:plotId/timeline',
        pageBuilder: (_, GoRouterState state) => AppPage(
          child: PlotTimelinePage(plotId: state.pathParameters['plotId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/plots/:plotId',
        pageBuilder: (_, GoRouterState state) => AppPage(
          child: PlotDetailPage(plotId: state.pathParameters['plotId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/edit',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: CycleFormPage(cycleId: state.pathParameters['cycleId']),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/activities/new',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: ActivityFormPage(
            cycleId: state.pathParameters['cycleId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/activities/:activityId/edit',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: ActivityFormPage(
            cycleId: state.pathParameters['cycleId'] ?? '',
            activityId: state.pathParameters['activityId'],
          ),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/harvests/new',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: HarvestFormPage(
            cycleId: state.pathParameters['cycleId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/harvests/:harvestId/edit',
        pageBuilder: (_, GoRouterState state) => AppPage(
          transition: AppPageTransition.vertical,
          child: HarvestFormPage(
            cycleId: state.pathParameters['cycleId'] ?? '',
            harvestId: state.pathParameters['harvestId'],
          ),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId',
        pageBuilder: (_, GoRouterState state) => AppPage(
          child: CycleDetailPage(
            cycleId: state.pathParameters['cycleId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/diagnostics',
        pageBuilder: (_, _) => AppPage(child: const DiagnosticsHistoryPage()),
      ),
      GoRoute(
        path: '/sync/failed',
        pageBuilder: (_, _) => AppPage(child: const SyncFailedPage()),
      ),
      GoRoute(path: '/diagnostic', redirect: (_, _) => '/diagnostic/new'),
      GoRoute(
        path: '/diagnostic/new',
        pageBuilder: (_, _) => AppPage(
          transition: AppPageTransition.vertical,
          child: const DiagnosticNewPage(),
        ),
      ),
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        pageBuilder: (_, GoRouterState state) => AppPage(
          child: DiagnosticResultPage(
            diagnosticId: state.pathParameters['diagnosticId'] ?? '',
          ),
        ),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/gallery',
          pageBuilder: (_, _) => AppPage(child: const DesignGalleryPage()),
        ),
    ],
    redirect: (_, GoRouterState state) {
      final String path = state.uri.path;
      if (kDebugMode && path == '/dev/gallery') {
        return null;
      }
      final SessionState session = ref.read(sessionControllerProvider);
      if (session == SessionState.unknown) {
        return path == '/splash' ? null : '/splash';
      }
      if (session == SessionState.unauthenticated) {
        const Set<String> allowed = <String>{
          '/login',
          '/register',
          '/otp',
          '/forgot-password',
          '/legal/terms',
          '/legal/privacy',
        };
        return allowed.contains(path) ? null : '/login';
      }
      const Set<String> authenticatedRedirects = <String>{
        '/login',
        '/splash',
        '/register',
        '/otp',
        '/forgot-password',
      };
      final AsyncValue<MeData?> me = ref.read(meProvider);
      final bool profileLoaded = me.hasValue && me.value != null;
      final bool isAdmin = profileLoaded && me.value!.user.isAdmin;
      final bool isAdminRoute = path == '/admin' || path.startsWith('/admin/');
      if (!profileLoaded) {
        if (authenticatedRedirects.contains(path)) {
          return '/home';
        }
        return null;
      }
      if (isAdmin) {
        const Set<String> adminRedirects = <String>{
          '/login',
          '/splash',
          '/register',
          '/otp',
          '/forgot-password',
          '/home',
          '/search',
          '/profile',
          '/admin',
          '/sync/failed',
        };
        final bool farmerDetailRoute =
            path == '/plots' ||
            path.startsWith('/plots/') ||
            path == '/cycles' ||
            path.startsWith('/cycles/');
        return adminRedirects.contains(path) || farmerDetailRoute
            ? '/admin/overview'
            : null;
      }
      if (isAdminRoute) {
        return '/home';
      }
      return authenticatedRedirects.contains(path) ? '/home' : null;
    },
  );
});
