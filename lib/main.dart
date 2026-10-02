import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'core/api_client.dart';
import 'repositories/api_agency_repository.dart';
import 'repositories/agency_repository_contract.dart';
import 'router.dart';
import 'state/agency_state.dart';
import 'state/form_navigation_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>(
          create: (_) => buildDio(),
          dispose: (_, dio) => dio.close(force: true),
        ),
        ProxyProvider<Dio, AgencyRepositoryContract>(
          update: (_, dio, previous) => previous ?? ApiAgencyRepository(dio),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              AgencyState(context.read<AgencyRepositoryContract>()),
        ),
        Provider(create: (_) => FormNavigationGuard()),
      ],
      child: const AlibiApp(),
    ),
  );
}

class AlibiApp extends StatelessWidget {
  const AlibiApp({super.key});
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
    routerConfig: appRouter,
  );
}
