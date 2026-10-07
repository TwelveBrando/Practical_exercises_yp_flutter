import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:second_practice/state/auth_notifier.dart';
import 'auth_fixture.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/main.dart';
import 'package:second_practice/models/agency_record.dart';
import 'package:second_practice/models/client.dart';
import 'package:second_practice/repositories/agency_repository.dart';
import 'package:second_practice/router.dart';
import 'package:second_practice/state/agency_state.dart';
import 'package:second_practice/state/form_navigation_guard.dart';

void main() {
  late AgencyRepository repository;
  late GoRouter appRouter;
  final captureKey = GlobalKey();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto');
      loader.addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  Future<void> open(WidgetTester tester, String path) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    repository = AgencyRepository(await SharedPreferences.getInstance());
    await repository.initialize();
    final auth = await testAuth();
    appRouter = buildRouter(auth);
    addTearDown(appRouter.dispose);
    appRouter.go('/requests');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>(create: (_) => auth),
          ChangeNotifierProvider(create: (_) => AgencyState(repository)),
          Provider(create: (_) => FormNavigationGuard()),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: AlibiApp(router: appRouter),
        ),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go(path);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String text) async {
    final button = find.text(text).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('LAYOUT_SCREENSHOTS')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/layout-checks/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('all five edit forms are filled and responsive', (tester) async {
    await open(tester, '/requests/1/edit');
    for (final kind in EntityKind.values) {
      appRouter.go('${kind.path}/1/edit');
      await tester.pumpAndSettle();
      for (final width in [1300.0, 800.0, 360.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${kind.name}: $width');
        for (final element in find.byType(TextFormField).evaluate()) {
          final field = element.widget as TextFormField;
          expect(field.controller!.text, isNotEmpty);
          final rect = tester.getRect(find.byWidget(field));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(width - 16));
        }
        if ([EntityKind.requests, EntityKind.clients].contains(kind) &&
            [1300.0, 360.0].contains(width)) {
          await capture(tester, '${kind.name}-form-${width.toInt()}');
        }
        await tester.ensureVisible(find.text('Сохранить изменения'));
        expect(find.text('Сохранить изменения').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byType(TextFormField).first);
      }
    }
    appRouter.go('/requests');
    await tester.pumpAndSettle();
  });

  testWidgets('invalid request shows simultaneous errors at its fields', (
    tester,
  ) async {
    await open(tester, '/requests/new');
    await press(tester, 'Создать');
    expect(
      tester
          .state<FormFieldState<String>>(find.byKey(const ValueKey('code')))
          .errorText,
      'Обязательное поле',
    );
    expect(
      tester
          .state<FormFieldState<String>>(find.byKey(const ValueKey('title')))
          .errorText,
      'Обязательное поле',
    );
    expect(find.text('Выберите хотя бы одну запись'), findsNWidgets(2));
    expect(find.text('Выберите значение'), findsNWidgets(2));
    expect(repository.all(EntityKind.requests), hasLength(24));
    await tester.ensureVisible(find.byType(TextFormField).first);
    await capture(tester, 'request-validation');
    appRouter.go('/requests');
    await tester.pumpAndSettle();
  });

  testWidgets('duplicate email is displayed below the email field', (
    tester,
  ) async {
    await open(tester, '/clients/new');
    await enter(tester, 'name', 'Новый клиент');
    await enter(tester, 'email', 'i.petrov@example.com');
    await enter(tester, 'city', 'Москва');
    await enter(tester, 'cardNumber', 'CARD-0900');
    await press(tester, 'Создать');
    expect(
      tester
          .state<FormFieldState<String>>(find.byKey(const ValueKey('email')))
          .errorText,
      'Такое значение уже используется',
    );
    await press(tester, 'Отмена');
    await press(tester, 'Выйти');
  });

  testWidgets('changing service resets and narrows selected scenarios', (
    tester,
  ) async {
    await open(tester, '/requests/1/edit');
    final service = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<Object> &&
          widget.decoration.labelText == 'Услуга',
    );
    await tester.ensureVisible(service);
    await tester.tap(service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Срочная подготовка').last);
    await tester.pumpAndSettle();
    final multiple = find.byType(FormField<List<int>>);
    expect(
      tester.state<FormFieldState<List<int>>>(multiple.last).value,
      isEmpty,
    );
    expect(
      find.widgetWithText(FilterChip, 'Задержка транспорта'),
      findsNothing,
    );
    expect(
      find.widgetWithText(FilterChip, 'Неотложное домашнее дело'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilterChip, 'Непредвиденная очередь'),
      findsOneWidget,
    );
    await press(tester, 'Отмена');
    await press(tester, 'Выйти');
  });

  testWidgets('menu navigation and cancel warn about unsaved edits', (
    tester,
  ) async {
    await open(tester, '/clients/1/edit');
    final original = repository.byId(EntityKind.clients, 1)!.name;
    await enter(tester, 'name', 'Несохранённое имя');
    await tester.tap(find.text('Заявки'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await press(tester, 'Остаться');
    expect(find.text('Редактирование: клиент'), findsOneWidget);
    await press(tester, 'Отмена');
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await press(tester, 'Выйти');
    expect(appRouter.routeInformationProvider.value.uri.path, '/clients');
    expect(repository.byId(EntityKind.clients, 1)!.name, original);
  });

  testWidgets('created client and nested card survive repository reload', (
    tester,
  ) async {
    await open(tester, '/clients/new');
    await enter(tester, 'name', 'Тестовый клиент');
    await enter(tester, 'email', 'test@example.com');
    await enter(tester, 'city', 'Москва');
    await enter(tester, 'cardNumber', 'CARD-0900');
    await enter(tester, 'cardPoints', '42');
    await press(tester, 'Создать');
    expect(appRouter.routeInformationProvider.value.uri.path, '/clients/13');
    final restored = AgencyRepository(repository.preferences);
    await restored.initialize();
    final client = restored.byId(EntityKind.clients, 13) as Client;
    expect(client.name, 'Тестовый клиент');
    expect(client.card!.number, 'CARD-0900');
    expect(client.card!.points, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked service cannot be deleted and counts are shown', (
    tester,
  ) async {
    await open(tester, '/services');
    await tester.tap(find.byTooltip('В корзину').first);
    await tester.pumpAndSettle();
    await press(tester, 'В корзину');
    expect(find.text('Действие не выполнено'), findsOneWidget);
    expect(find.textContaining('заявки: 8'), findsOneWidget);
    expect(find.textContaining('сценарии: 2'), findsOneWidget);
    await capture(tester, 'related-service-delete');
    await press(tester, 'Понятно');
    expect(
      repository.all(EntityKind.services).where((record) => record.isDeleted),
      isEmpty,
    );
  });

  testWidgets('debounced search preserves the typed text and cursor', (
    tester,
  ) async {
    await open(tester, '/requests');
    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.prefixIcon is Icon &&
          (widget.decoration!.prefixIcon as Icon).icon == Icons.search,
    );
    await tester.enterText(search, 'встреч');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    final controller = tester.widget<TextField>(search).controller!;
    expect(controller.text, 'встреч');
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, 6);
    await tester.enterText(search, 'встреча');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(controller.text, 'встреча');
    expect(
      appRouter.routeInformationProvider.value.uri.queryParameters['search'],
      'встреча',
    );
  });
}
