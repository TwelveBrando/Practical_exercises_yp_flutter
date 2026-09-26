import 'package:flutter/material.dart';
import 'filter_menu.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    runSpacing: 6,
    children: [
      IconButton(
        tooltip: 'Первая страница',
        onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
        icon: const Icon(Icons.first_page),
      ),
      IconButton(
        tooltip: 'Предыдущая',
        onPressed: currentPage > 1
            ? () => onPageChanged(currentPage - 1)
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Страница $currentPage из $totalPages · $totalRecords записей'),
      IconButton(
        tooltip: 'Следующая',
        onPressed: currentPage < totalPages
            ? () => onPageChanged(currentPage + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: 'Последняя страница',
        onPressed: currentPage < totalPages
            ? () => onPageChanged(totalPages)
            : null,
        icon: const Icon(Icons.last_page),
      ),
      const SizedBox(width: 8),
      const Text('На странице'),
      FilterMenu<int>(
        value: pageSize,
        options: const [
          FilterMenuOption(value: 10, label: '10'),
          FilterMenuOption(value: 25, label: '25'),
          FilterMenuOption(value: 50, label: '50'),
        ],
        onSelected: (selectedPageSize) {
          if (selectedPageSize != null) {
            onPageSizeChanged(selectedPageSize);
          }
        },
      ),
    ],
  );
}
