import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:second_practice/main.dart';
import 'package:second_practice/repositories/client_repository.dart';
import 'package:second_practice/repositories/in_memory_client_repository.dart';
import 'package:second_practice/repositories/in_memory_request_repository.dart';
import 'package:second_practice/repositories/request_repository.dart';
import 'package:second_practice/router.dart';
import 'package:second_practice/state/catalog_notifiers.dart';

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    // Real Cyrillic glyphs for optional screenshots on the development machine.
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });

  testWidgets('catalog actions stay visible and cards can scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureKey = GlobalKey();
    final requests = InMemoryRequestRepository();
    final clients = InMemoryClientRepository();
    // Deleted records have three actions instead of two.
    await requests.softDelete(9);
    await clients.softDelete(1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RequestRepository>.value(value: requests),
          Provider<ClientRepository>.value(value: clients),
          ChangeNotifierProvider(create: (_) => RequestListNotifier(requests)),
          ChangeNotifierProvider(create: (_) => ClientListNotifier(clients)),
        ],
        child: RepaintBoundary(key: captureKey, child: const AlibiApp()),
      ),
    );

    for (final catalog in ['requests', 'clients']) {
      appRouter.go('/$catalog?deleted=1');
      await tester.pumpAndSettle();

      for (final width in [
        1300.0,
        1920.0,
        1132.0,
        1100.0,
        800.0,
        492.0,
        360.0,
      ]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$catalog at $width');

        final buttons = find.widgetWithIcon(IconButton, Icons.open_in_new);
        expect(buttons, findsWidgets);
        for (final element in buttons.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(width - 16));
        }
        expect(buttons.hitTestable(), findsWidgets);

        if (width >= 1132) {
          expect(find.byType(DataTable), findsOneWidget);
          expect(
            tester.getSize(find.byType(DataTable)).width,
            width > 1280 ? 1248 : width - 32,
          );
          final tableRect = tester.getRect(find.byType(DataTable));
          expect(
            tester.getRect(find.text('Действия')).right,
            lessThanOrEqualTo(tableRect.right),
          );
          for (final tooltip in ['Восстановить', 'Удалить навсегда']) {
            expect(
              tester.getRect(find.byTooltip(tooltip).first).right,
              lessThanOrEqualTo(tableRect.right),
            );
          }
        } else {
          expect(find.byType(DataTable), findsNothing);
          final list = find.byType(ListView);
          final scrollable = find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          );
          final state = tester.state<ScrollableState>(scrollable);
          await tester.drag(list, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(state.position.pixels, greaterThan(0));
          state.position.jumpTo(0);
          await tester.pumpAndSettle();
        }

        if (const bool.fromEnvironment('LAYOUT_SCREENSHOTS') &&
            [1300.0, 1132.0, 360.0].contains(width)) {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout-checks/$catalog-${width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.open_in_new).hitTestable().first,
      );
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        matches('^/$catalog/[0-9]+'),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
