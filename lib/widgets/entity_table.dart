import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
    this.flex = 1,
  });
  final String label;
  final String? sortField;
  final bool numeric;
  final double flex;
  final Widget Function(T) build;
}

class EntityTable<T> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.titleOf,
    this.scrollable = true,
  });
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final ValueChanged<String>? onSort;
  final List<Widget> Function(T)? actions;
  final String Function(T)? titleOf;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (MediaQuery.sizeOf(context).width < 1280) {
        final columnsCount = constraints.maxWidth >= 600 ? 2 : 1;
        return ListView.builder(
          shrinkWrap: !scrollable,
          primary: scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          itemCount: (items.length / columnsCount).ceil(),
          itemBuilder: (context, index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var columnIndex = 0;
                  columnIndex < columnsCount;
                  columnIndex++
                ) ...[
                  if (columnIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    child: index * columnsCount + columnIndex >= items.length
                        ? const SizedBox.shrink()
                        : _card(
                            context,
                            items[index * columnsCount + columnIndex],
                          ),
                  ),
                ],
              ],
            );
          },
        );
      }
      return _table(context, constraints);
    },
  );

  Widget _card(BuildContext context, T item) {
    final id = idOf(item);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onToggleSelect != null)
                  Checkbox(
                    value: selected.contains(id),
                    onChanged: (_) => onToggleSelect!(id),
                  ),
                Expanded(
                  child: Text(
                    titleOf?.call(item) ?? columns.first.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (actions != null)
              Wrap(alignment: WrapAlignment.end, children: actions!(item)),
            ...columns
                .skip(titleOf == null ? 0 : 1)
                .map(
                  (column) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(
                            column.label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Expanded(child: column.build(item)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _table(BuildContext context, BoxConstraints constraints) {
    final activeSortColumnIndex = columns.indexWhere(
      (column) => column.sortField == sortField,
    );
    final rowActions = [
      for (final item in items) actions?.call(item) ?? <Widget>[],
    ];
    final actionCount = rowActions.fold<int>(
      0,
      (largest, buttons) => buttons.length > largest ? buttons.length : largest,
    );
    final table = DataTable(
      horizontalMargin: 12,
      checkboxHorizontalMargin: 8,
      columnSpacing: 24,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 64,
      sortColumnIndex: activeSortColumnIndex < 0
          ? null
          : activeSortColumnIndex + (onToggleSelect == null ? 0 : 1),
      sortAscending: sortAscending,
      columns: [
        if (onToggleSelect != null)
          const DataColumn(label: Text(''), columnWidth: FixedColumnWidth(60)),
        ...columns.map(
          (column) => DataColumn(
            label: Flexible(child: Text(column.label, maxLines: 2)),
            columnWidth: FlexColumnWidth(column.flex),
            numeric: column.numeric,
            onSort: column.sortField == null || onSort == null
                ? null
                : (columnIndex, ascending) => onSort!(column.sortField!),
          ),
        ),
        if (actions != null)
          DataColumn(
            label: const Flexible(
              child: Text(
                'Действия',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            columnWidth: FixedColumnWidth(actionCount * 48 + 24),
          ),
      ],
      rows: items.asMap().entries.map((entry) {
        final item = entry.value;
        final id = idOf(item);
        return DataRow(
          selected: selected.contains(id),
          cells: [
            if (onToggleSelect != null)
              DataCell(
                Checkbox(
                  value: selected.contains(id),
                  onChanged: (_) => onToggleSelect!(id),
                ),
              ),
            ...columns.map(
              (column) => DataCell(
                DefaultTextStyle.merge(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: column.build(item),
                ),
              ),
            ),
            if (actions != null)
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: rowActions[entry.key],
                ),
              ),
          ],
        );
      }).toList(),
    );
    final horizontal = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: constraints.maxWidth < 1000 ? 1000 : constraints.maxWidth,
        child: table,
      ),
    );
    if (!scrollable) return horizontal;
    return SingleChildScrollView(primary: true, child: horizontal);
  }
}
