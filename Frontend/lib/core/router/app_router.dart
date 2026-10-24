import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/common/placeholder_page.dart';
import '../../features/dev_gallery/design_gallery_page.dart';
import '../../features/home/home_shell.dart';
import '../config/app_config.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';

final Provider<String> startRouteProvider = Provider<String>(
  (Ref ref) => AppConfig.startRoute,
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionControllerProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: kDebugMode ? ref.read(startRouteProvider) : '/splash',
    refreshListenable: refresh,
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (_, _) => const PlaceholderPage(title: 'Chargement'),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const PlaceholderPage(title: 'Inscription'),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, _) => const PlaceholderPage(title: 'Vérification OTP'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
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
        };
        return allowed.contains(path) ? null : '/login';
      }
      const Set<String> authenticatedRedirects = <String>{
        '/login',
        '/splash',
        '/register',
      };
      return authenticatedRedirects.contains(path) ? '/home' : null;
    },
  );
});
