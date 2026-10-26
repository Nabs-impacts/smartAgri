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
import '../../features/dev_gallery/design_gallery_page.dart';
import '../../features/diagnostics/presentation/diagnostic_new_page.dart';
import '../../features/diagnostics/presentation/diagnostics_history_page.dart';
import '../../features/diagnostics/presentation/diagnostic_result_page.dart';
import '../../features/farms/presentation/farm_detail_page.dart';
import '../../features/farms/presentation/farm_form_page.dart';
import '../../features/farms/presentation/farms_page.dart';
import '../../features/farms/presentation/plot_detail_page.dart';
import '../../features/farms/presentation/plot_form_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/legal/legal_page.dart';
import '../../features/profile/data/me_repository.dart';
import '../../features/profile/profile_page.dart';
import '../../features/search/search_page.dart';
import '../config/app_config.dart';
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
        builder: (_, _) => const PlaceholderPage(title: 'Chargement'),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/otp',
        redirect: (_, GoRouterState state) =>
            state.extra is OtpArgs ? null : '/login',
        builder: (_, GoRouterState state) =>
            OtpPage(args: state.extra! as OtpArgs),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const LegalPage(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const LegalPage(document: LegalDocument.privacy),
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
              GoRoute(path: '/home', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
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
                builder: (_, _) => const AdminOverviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/yields',
                builder: (_, _) => const AdminYieldsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/profile',
                builder: (_, _) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/admin', redirect: (_, _) => '/admin/overview'),
      GoRoute(path: '/farms', builder: (_, _) => const FarmsPage()),
      GoRoute(path: '/farms/new', builder: (_, _) => const FarmFormPage()),
      GoRoute(
        path: '/farms/:farmId/edit',
        builder: (_, GoRouterState state) =>
            FarmFormPage(farmId: state.pathParameters['farmId']),
      ),
      GoRoute(
        path: '/farms/:farmId/plots/new',
        builder: (_, GoRouterState state) =>
            PlotFormPage(farmId: state.pathParameters['farmId']),
      ),
      GoRoute(
        path: '/farms/:farmId',
        builder: (_, GoRouterState state) =>
            FarmDetailPage(farmId: state.pathParameters['farmId'] ?? ''),
      ),
      GoRoute(
        path: '/plots/:plotId/edit',
        builder: (_, GoRouterState state) =>
            PlotFormPage(plotId: state.pathParameters['plotId']),
      ),
      GoRoute(
        path: '/plots/:plotId',
        builder: (_, GoRouterState state) =>
            PlotDetailPage(plotId: state.pathParameters['plotId'] ?? ''),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (_, _) => const DiagnosticsHistoryPage(),
      ),
      GoRoute(path: '/diagnostic', redirect: (_, _) => '/diagnostic/new'),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const DiagnosticNewPage(),
      ),
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        builder: (_, GoRouterState state) => DiagnosticResultPage(
          diagnosticId: state.pathParameters['diagnosticId'] ?? '',
        ),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/gallery',
          builder: (_, _) => const DesignGalleryPage(),
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
        };
        return adminRedirects.contains(path) ? '/admin/overview' : null;
      }
      if (isAdminRoute) {
        return '/home';
      }
      return authenticatedRedirects.contains(path) ? '/home' : null;
    },
  );
});
