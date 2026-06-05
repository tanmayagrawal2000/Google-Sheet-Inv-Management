import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/user_session_cubit.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/presentation/custom_sign_in_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../features/inventory/presentation/category_screen.dart';
import '../../features/inventory/presentation/damage_log_screen.dart';
import '../../features/inventory/presentation/item_detail_screen.dart';
import '../../features/inventory/presentation/room_screen.dart';
import '../../features/issues/presentation/issues_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../shared/models/inventory_item.dart';
import 'go_router_refresh_stream.dart';

/// Builds the app router driven by both [authCubit] (Google OAuth layer)
/// and [sessionCubit] (custom username/password layer).
GoRouter buildRouter(AuthCubit authCubit, UserSessionCubit sessionCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream.multi([
      authCubit.stream,
      sessionCubit.stream,
    ]),
    redirect: (context, state) {
      final authStatus = authCubit.state.status;
      final session = sessionCubit.state;
      final loc = state.matchedLocation;

      switch (authStatus) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          // No Google master account — show Google OAuth (admin setup).
          return loc == '/sign-in' ? null : '/sign-in';
        case AuthStatus.signedIn:
          // Google account established; now gate on custom user session.
          if (!session.isAuthenticated) {
            return loc == '/custom-login' ? null : '/custom-login';
          }
          // Fully authenticated — send away from auth screens.
          if (loc == '/sign-in' ||
              loc == '/splash' ||
              loc == '/custom-login') {
            return '/';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: '/custom-login',
          builder: (_, __) => const CustomSignInScreen()),
      GoRoute(path: '/', builder: (_, __) => const RoomsScreen()),
      GoRoute(
          path: '/users',
          builder: (_, __) => const UserManagementScreen()),
      GoRoute(
        path: '/room/:id',
        builder: (context, state) => RoomScreen(
          spreadsheetId: state.pathParameters['id']!,
          roomName: state.uri.queryParameters['name'] ?? 'Room',
        ),
      ),
      GoRoute(
        path: '/room/:id/log',
        builder: (context, state) => IssuesScreen(
          spreadsheetId: state.pathParameters['id']!,
          roomName: state.uri.queryParameters['name'] ?? 'Room',
        ),
      ),
      GoRoute(
        path: '/room/:id/damage-log',
        builder: (context, state) => DamageLogScreen(
          spreadsheetId: state.pathParameters['id']!,
          roomName: state.uri.queryParameters['name'] ?? 'Room',
        ),
      ),
      GoRoute(
        path: '/room/:id/category/:tab',
        builder: (context, state) => CategoryScreen(
          spreadsheetId: state.pathParameters['id']!,
          tab: Uri.decodeComponent(state.pathParameters['tab']!),
          roomName: state.uri.queryParameters['name'] ?? 'Room',
        ),
      ),
      GoRoute(
        path: '/room/:id/category/:tab/item',
        builder: (context, state) => ItemDetailScreen(
          spreadsheetId: state.pathParameters['id']!,
          tab: Uri.decodeComponent(state.pathParameters['tab']!),
          item: state.extra as InventoryItem,
        ),
      ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
