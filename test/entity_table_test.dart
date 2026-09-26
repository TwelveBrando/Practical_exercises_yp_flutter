import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/widgets/entity_table.dart';

void main() {
  testWidgets('desktop table fills the available width', (tester) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: EntityTable<int>(
              items: const [1],
              idOf: (item) => item,
              onToggleSelect: (_) {},
              columns: [
                for (var index = 0; index < 6; index++)
                  TableColumnSpec<int>(
                    label: 'Column $index',
                    build: (item) => Text('Value $item'),
                  ),
              ],
              actions: (item) => [
                IconButton(onPressed: () {}, icon: const Icon(Icons.delete)),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(DataTable)).width, 1268);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
