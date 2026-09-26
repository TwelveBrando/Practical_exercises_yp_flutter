import 'package:flutter/material.dart';

class FilterMenuOption<T> {
  const FilterMenuOption({required this.value, required this.label});

  final T? value;
  final String label;
}

class FilterMenu<T> extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T? value;
  final List<FilterMenuOption<T>> options;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedOption = options.firstWhere(
      (option) => option.value == value,
      orElse: () => options.first,
    );

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: () => onSelected(option.value),
            child: Text(option.label),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.expand_more),
        label: Text(
          selectedOption.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
