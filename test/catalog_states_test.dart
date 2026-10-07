import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/core/api_exceptions.dart';
import 'package:second_practice/main.dart';
import 'package:second_practice/models/agency_record.dart';
import 'package:second_practice/models/app_user.dart';
import 'package:second_practice/models/page_result.dart';
import 'package:second_practice/models/record_query.dart';
import 'package:second_practice/repositories/agency_repository.dart';
import 'package:second_practice/router.dart';
import 'package:second_practice/state/agency_state.dart';
import 'package:second_practice/state/auth_notifier.dart';
import 'package:second_practice/state/form_navigation_guard.dart';
import 'package:second_practice/widgets/entity_table.dart';
import 'auth_fixture.dart';

class ControlledRepository extends AgencyRepository {
  ControlledRepository(super.preferences);
  Future<PageResult<AgencyRecord>> Function()? response;
  @override
  Future<PageResult<AgencyRecord>> find(EntityKind kind, RecordQuery query) =>
      response?.call() ?? super.find(kind, query);
}

void main() {
  Future<ControlledRepository> open(
    WidgetTester tester, {
    Role role = Role.client,
    Future<PageResult<AgencyRecord>> Function()? response,
    String route = '/services',
    double width = 1280,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = ControlledRepository(
      await SharedPreferences.getInstance(),
    );
    await repository.initialize();
    repository.response = response;
    final auth = await testAuth(role: role);
    final router = buildRouter(auth);
    addTearDown(router.dispose);
    router.go(route);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>(create: (_) => auth),
          ChangeNotifierProvider(create: (_) => AgencyState(repository)),
          Provider(create: (_) => FormNavigationGuard()),
        ],
        child: AlibiApp(router: router),
      ),
    );
    await tester.pump();
    return repository;
  }

  testWidgets('catalog shows loading until response arrives', (tester) async {
    final pending = Completer<PageResult<AgencyRecord>>();
    await open(tester, response: () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Записи не найдены. Измените условия поиска.'),
      findsNothing,
    );
    pending.complete(PageResult.empty());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('empty result shows a message instead of a spinner', (
    tester,
  ) async {
    await open(tester, response: () async => PageResult.empty());
    await tester.pumpAndSettle();
    expect(
      find.text('Записи не найдены. Измените условия поиска.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('network error can be retried without rebuilding the app', (
    tester,
  ) async {
    final repository = await open(
      tester,
      response: () async => throw const NetworkException(),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Сервер недоступен. Проверьте соединение.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
    repository.response = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Бытовое объяснение'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });
  testWidgets('empty service form displays validation and creates no record', (
    tester,
  ) async {
    final repository = await open(
      tester,
      role: Role.employee,
      route: '/services/new',
    );
    await tester.pumpAndSettle();
    final before = repository.all(EntityKind.services).length;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Создать'));
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Обязательное поле'), findsWidgets);
    expect(repository.all(EntityKind.services).length, before);
  });
  testWidgets('client sees the catalog without management actions', (
    tester,
  ) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Бытовое объяснение'), findsOneWidget);
    expect(find.text('Создать'), findsNothing);
    expect(find.byTooltip('Редактировать'), findsNothing);
    expect(find.byTooltip('В корзину'), findsNothing);
    expect(find.byTooltip('Карточка записи'), findsWidgets);
  });
  testWidgets('navigation and table change after resizing without a reload', (
    tester,
  ) async {
    await open(tester, width: 360);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    for (final width in [768.0, 1280.0, 1920.0, 360.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(
        find.byType(NavigationBar),
        width < 600 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationRail),
        width >= 600 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(DataTable),
        width >= 1280 ? findsOneWidget : findsNothing,
      );
      expect(find.byType(EntityTable<AgencyRecord>), findsOneWidget);
    }
  });
  testWidgets('keyboard can focus search and edit its value', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    final search = find.byType(TextField).first;
    await tester.tap(search);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.enterText(search, 'Не существующая услуга');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      find.text('Записи не найдены. Измените условия поиска.'),
      findsOneWidget,
    );
  });
}
