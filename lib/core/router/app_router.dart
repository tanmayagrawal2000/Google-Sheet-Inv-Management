import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/inventory/presentation/category_screen.dart';
import '../../features/inventory/presentation/item_detail_screen.dart';
import '../../features/inventory/presentation/room_screen.dart';
import '../../features/issues/presentation/issues_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../shared/models/inventory_item.dart';
import 'go_router_refresh_stream.dart';

/// Builds the app router with an auth gate driven by [authCubit].
GoRouter buildRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final status = authCubit.state.status;
      final loc = state.matchedLocation;
      switch (status) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return loc == '/sign-in' ? null : '/sign-in';
        case AuthStatus.signedIn:
          return (loc == '/sign-in' || loc == '/splash') ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/', builder: (_, __) => const RoomsScreen()),
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
