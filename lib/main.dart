import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'repositories/auth_api.dart';
import 'state/auth_notifier.dart';
import 'widgets/inactivity_watcher.dart';
import 'core/api_client.dart';
import 'repositories/api_agency_repository.dart';
import 'repositories/agency_repository_contract.dart';
import 'router.dart';
import 'state/agency_state.dart';
import 'state/form_navigation_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  AuthNotifier? auth;
  final dio = buildDio(
    tokenProvider: () => auth?.accessToken,
    refreshToken: () => auth!.refreshTokens(),
    onUnauthorized: () =>
        auth!.logout(reason: 'Сессия завершена. Войдите снова.'),
  );
  auth = AuthNotifier(prefs, AuthApi(dio));
  await auth.restore();
  final router = buildRouter(auth);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        Provider<Dio>.value(value: dio),
        ProxyProvider2<Dio, AuthNotifier, AgencyRepositoryContract>(
          update: (_, dio, session, previous) {
            final owner = '${session.user?.id}:${session.user?.role.name}';
            if (previous is ApiAgencyRepository &&
                previous.sessionOwner == owner) {
              return previous;
            }
            previous?.cancelFind();
            return ApiAgencyRepository(dio, sessionOwner: owner);
          },
        ),
        ChangeNotifierProxyProvider<AgencyRepositoryContract, AgencyState>(
          create: (context) =>
              AgencyState(context.read<AgencyRepositoryContract>()),
          update: (_, repository, previous) =>
              previous?.repository == repository
              ? previous!
              : AgencyState(repository),
        ),
        Provider(create: (_) => FormNavigationGuard()),
      ],
      child: InactivityWatcher(
        auth: auth,
        child: AlibiApp(router: router),
      ),
    ),
  );
}

class AlibiApp extends StatelessWidget {
  const AlibiApp({super.key, required this.router});
  final GoRouter router;
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Агентство Alibi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A4E56)),
      scaffoldBackgroundColor: const Color(0xFFFAF8F6),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF8F6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFD9CFCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF7A4E56), width: 1.5),
        ),
        isDense: true,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFE9E1DE)),
        ),
      ),
    ),
    routerConfig: router,
  );
}
