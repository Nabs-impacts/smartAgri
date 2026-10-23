import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';
import '../../features/dev_gallery/design_gallery_page.dart';
import '../../features/home/home_shell.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final SessionState session = ref.watch(sessionControllerProvider);
  return GoRouter(
    initialLocation: '/splash',
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (_, _) => const PlaceholderPage(title: 'Chargement'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const PlaceholderPage(title: 'Connexion'),
      ),
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
        builder: (_, _) => const PlaceholderPage(title: 'Mot de passe oublié'),
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
      if (session == SessionState.unknown) {
        return path == '/splash' ? null : '/splash';
      }
      if (session == SessionState.unauthenticated) {
        const Set<String> allowed = <String>{
          '/login',
          '/register',
          '/otp',
          '/forgot-password',
          '/dev/gallery',
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
