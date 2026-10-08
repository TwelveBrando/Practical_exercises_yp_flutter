import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/core/api_exceptions.dart';
import 'package:second_practice/main.dart';
import 'package:second_practice/models/pricing_quote.dart';
import 'package:second_practice/router.dart';
import 'package:second_practice/state/auth_notifier.dart';
import 'package:second_practice/state/form_navigation_guard.dart';
import 'auth_fixture.dart';

class QuoteApi extends FakeAuthApi {
  Future<PricingQuote> Function(int, int)? response;
  final calls = <(int, int)>[];
  @override
  Future<PricingQuote> estimate(int requestId, int discount) {
    calls.add((requestId, discount));
    return response?.call(requestId, discount) ??
        Future.value(
          PricingQuote.calculate(
            base: 1000,
            urgencyLevel: 3,
            preparationMinutes: 45,
            discountPercent: discount,
          ),
        );
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    QuoteApi api, {
    double width = 1280,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = AuthNotifier(await SharedPreferences.getInstance(), api);
    await auth.login('test', 'password');
    final router = buildRouter(auth);
    addTearDown(router.dispose);
    router.go('/requests/1/estimate');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>(create: (_) => auth),
          Provider(create: (_) => FormNavigationGuard()),
        ],
        child: AlibiApp(router: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('estimate displays loading and then a complete calculation', (
    tester,
  ) async {
    final pending = Completer<PricingQuote>();
    final api = QuoteApi()..response = (_, _) => pending.future;
    await open(tester, api);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(
      PricingQuote.calculate(
        base: 1000,
        urgencyLevel: 3,
        preparationMinutes: 45,
        discountPercent: 10,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1755 ₽'), findsOneWidget);
    expect(find.text('Подготовка (45 мин.)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid discount stays in the form and causes no request', (
    tester,
  ) async {
    final api = QuoteApi();
    await open(tester, api);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '31');
    await tester.tap(find.text('Пересчитать'));
    await tester.pumpAndSettle();
    expect(api.calls, [(1, 0)]);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '10');
    await tester.tap(find.text('Пересчитать'));
    await tester.pumpAndSettle();
    expect(api.calls.last, (1, 10));
    expect(find.text('1755 ₽'), findsOneWidget);
  });
  testWidgets('network failure can be retried without leaving the estimate', (
    tester,
  ) async {
    final api = QuoteApi()
      ..response = (_, _) => Future.error(const NetworkException());
    await open(tester, api);
    await tester.pumpAndSettle();
    expect(
      find.text('Сервер недоступен. Проверьте соединение.'),
      findsOneWidget,
    );
    api.response = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('1950 ₽'), findsOneWidget);
  });
  testWidgets('estimate remains usable at 360 pixels', (tester) async {
    await open(tester, QuoteApi(), width: 360);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Итоговая стоимость'));
    expect(find.text('1950 ₽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
