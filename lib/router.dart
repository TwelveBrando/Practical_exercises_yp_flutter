import 'package:go_router/go_router.dart';
import 'models/client_query.dart';
import 'models/request_query.dart';
import 'screens/client_list_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/request_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/requests',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/requests'),
    GoRoute(
      path: '/requests',
      builder: (context, state) =>
          RequestListScreen(query: RequestQuery.fromUri(state.uri)),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return id == null
                ? NotFoundScreen(location: state.uri.toString())
                : DetailScreen.request(id: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/clients',
      builder: (context, state) =>
          ClientListScreen(query: ClientQuery.fromUri(state.uri)),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return id == null
                ? NotFoundScreen(location: state.uri.toString())
                : DetailScreen.client(id: id);
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);
