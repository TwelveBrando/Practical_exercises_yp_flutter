import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'repositories/client_repository.dart';
import 'repositories/in_memory_client_repository.dart';
import 'repositories/in_memory_request_repository.dart';
import 'repositories/request_repository.dart';
import 'router.dart';
import 'state/catalog_notifiers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        Provider<ClientRepository>(create: (_) => InMemoryClientRepository()),
        Provider<RequestRepository>(create: (_) => InMemoryRequestRepository()),
        ChangeNotifierProvider(
          create: (context) =>
              ClientListNotifier(context.read<ClientRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              RequestListNotifier(context.read<RequestRepository>()),
        ),
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
