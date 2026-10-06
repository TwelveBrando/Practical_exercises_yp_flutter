import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/agency_record.dart';
import 'models/app_user.dart';
import 'models/record_query.dart';
import 'screens/agency_catalog_screen.dart';
import 'screens/agency_form_screen.dart';
import 'screens/agency_detail_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/account_screen.dart';
import 'screens/users_screen.dart';
import 'state/auth_notifier.dart';
import 'state/form_navigation_guard.dart';
import 'widgets/app_shell.dart';

String? safeDestination(String? value) {
  if (value == null ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      value.contains('\\')) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      ['/login', '/register', '/forbidden'].contains(uri.path)) {
    return null;
  }
  return uri.toString();
}

bool allowedPath(Role role, String path) {
  if (path == '/forbidden' || path == '/') return true;
  if (path == '/my-requests') return role.allows(Operation.ownRequests);
  if (path == '/work') return role.allows(Operation.work);
  if (path == '/admin/users') return role.allows(Operation.users);
  if (path == '/admin/statistics') return role.allows(Operation.statistics);
  for (final kind in EntityKind.values) {
    if (path == kind.path || path.startsWith('${kind.path}/')) {
      if (path.endsWith('/new') || path.endsWith('/edit')) {
        return role.allows(Operation.write);
      }
      if (role == Role.client &&
          kind == EntityKind.requests &&
          RegExp(r'^/requests/\d+$').hasMatch(path)) {
        return true;
      }
      return role.canView(kind);
    }
  }
  return true;
}

GoRouter buildRouter(AuthNotifier auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (context, state) {
    final path = state.uri.path;
    final public = path == '/login' || path == '/register';
    if (!auth.isAuthenticated && !public) {
      return Uri(
        path: '/login',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (auth.isAuthenticated && public) {
      return safeDestination(state.uri.queryParameters['from']) ??
          auth.user!.role.home;
    }
    if (auth.isAuthenticated && !allowedPath(auth.user!.role, path)) {
      return '/forbidden';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => AuthScreen(
        from: state.uri.queryParameters['from'],
        registered: state.uri.queryParameters['registered'] == '1',
      ),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) =>
          AuthScreen(register: true, from: state.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) => auth.user?.role.home ?? '/login',
    ),
    GoRoute(
      path: '/forbidden',
      builder: (context, state) => AppShell(
        title: 'Доступ запрещён',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Недостаточно прав для открытия этого раздела.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(auth.user!.role.home),
                child: const Text('В свой кабинет'),
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/my-requests',
      builder: (context, state) =>
          const AccountScreen(section: AccountSection.client),
    ),
    GoRoute(
      path: '/work',
      builder: (context, state) =>
          const AccountScreen(section: AccountSection.work),
    ),
    GoRoute(
      path: '/admin/statistics',
      builder: (context, state) =>
          const AccountScreen(section: AccountSection.statistics),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UsersScreen(),
    ),
    for (final kind in EntityKind.values) ...[
      GoRoute(
        path: '${kind.path}/new',
        builder: (context, state) =>
            AgencyFormScreen(key: ValueKey('${kind.name}:new'), kind: kind),
        onExit: (context, state) => !auth.isAuthenticated
            ? true
            : context.read<FormNavigationGuard>().confirmExit(),
      ),
      GoRoute(
        path: '${kind.path}/:id/edit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? NotFoundScreen(location: state.uri.toString())
              : AgencyFormScreen(
                  key: ValueKey('${kind.name}:$id'),
                  kind: kind,
                  id: id,
                );
        },
        onExit: (context, state) => !auth.isAuthenticated
            ? true
            : context.read<FormNavigationGuard>().confirmExit(),
      ),
      GoRoute(
        path: '${kind.path}/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? NotFoundScreen(location: state.uri.toString())
              : AgencyDetailScreen(kind: kind, id: id);
        },
      ),
      GoRoute(
        path: kind.path,
        builder: (context, state) => AgencyCatalogScreen(
          key: ValueKey(kind),
          kind: kind,
          query: RecordQuery.fromUri(state.uri),
        ),
      ),
    ],
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);
