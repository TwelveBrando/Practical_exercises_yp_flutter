import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/agency_record.dart';
import 'models/record_query.dart';
import 'screens/agency_catalog_screen.dart';
import 'screens/agency_form_screen.dart';
import 'screens/agency_detail_screen.dart';
import 'screens/not_found_screen.dart';
import 'state/form_navigation_guard.dart';

final appRouter = GoRouter(
  initialLocation: '/requests',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/requests'),
    for (final kind in EntityKind.values) ...[
      GoRoute(
        path: '${kind.path}/new',
        builder: (context, state) =>
            AgencyFormScreen(key: ValueKey('${kind.name}:new'), kind: kind),
        onExit: (context, state) =>
            context.read<FormNavigationGuard>().confirmExit(),
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
        onExit: (context, state) =>
            context.read<FormNavigationGuard>().confirmExit(),
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
