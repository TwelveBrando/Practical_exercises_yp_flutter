import 'package:flutter/material.dart';
import '../validation/record_fields.dart';
import '../models/json_readers.dart';

class RecordForm extends StatelessWidget {
  const RecordForm({
    super.key,
    required this.formKey,
    required this.fields,
    required this.values,
    required this.controllers,
    required this.onChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.saving,
    required this.editing,
    this.errors = const {},
  });
  final GlobalKey<FormState> formKey;
  final List<RecordField> fields;
  final Map<String, dynamic> values;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, Object? value) onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool saving;
  final bool editing;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;
        String? section;
        final children = <Widget>[];
        for (final field in fields) {
          if (field.section != section) {
            section = field.section;
            if (section != null) {
              children.add(
                SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      section,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              );
            }
          }
          children.add(
            SizedBox(
              width: field.input == FieldInput.multiple || field.lines > 1
                  ? constraints.maxWidth
                  : width,
              child: _input(context, field),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 16, runSpacing: 18, children: children),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    saving
                        ? 'Сохранение…'
                        : editing
                        ? 'Сохранить изменения'
                        : 'Создать',
                  ),
                ),
                OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _input(BuildContext context, RecordField field) {
    String? validate(Object? value) =>
        errors[field.key] ?? field.validate(value);
    final decoration = InputDecoration(labelText: field.label);
    if (field.input == FieldInput.select) {
      final value = values[field.key];
      final available = field.options.any((option) => option.value == value);
      return DropdownButtonFormField<Object>(
        key: ValueKey('${field.key}:$value'),
        initialValue: available ? value : null,
        isExpanded: true,
        decoration: decoration,
        validator: validate,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        items: [
          for (final option in field.options)
            DropdownMenuItem(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: saving ? null : (value) => onChanged(field.key, value),
      );
    }
    if (field.input == FieldInput.multiple) {
      return FormField<List<int>>(
        key: ValueKey(
          '${field.key}:${field.options.map((option) => option.value).join(',')}',
        ),
        initialValue: readIds(values[field.key]),
        validator: validate,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        builder: (state) => InputDecorator(
          decoration: decoration.copyWith(
            errorText: state.errorText,
            helperText: field.options.isEmpty
                ? 'Нет доступных записей. Сначала добавьте их в соответствующий каталог.'
                : null,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in field.options)
                FilterChip(
                  label: Text(option.label),
                  selected: state.value?.contains(option.value) ?? false,
                  onSelected: saving
                      ? null
                      : (selected) {
                          final next = [...?state.value];
                          if (selected) {
                            next.add(option.value as int);
                          } else {
                            next.remove(option.value);
                          }
                          state.didChange(next);
                          onChanged(field.key, next);
                        },
                ),
            ],
          ),
        ),
      );
    }
    return TextFormField(
      key: ValueKey(field.key),
      controller: controllers[field.key],
      enabled: !saving,
      maxLines: field.lines,
      keyboardType: field.input == FieldInput.number
          ? TextInputType.number
          : field.key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: field.input == FieldInput.date
          ? decoration.copyWith(
              hintText: 'ГГГГ-ММ-ДД',
              suffixIcon: IconButton(
                tooltip: 'Выбрать дату',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: saving
                    ? null
                    : () async {
                        final parsed = DateTime.tryParse(
                          controllers[field.key]!.text,
                        );
                        final initial =
                            parsed != null &&
                                parsed.year >= 1900 &&
                                parsed.year <= 2100
                            ? parsed
                            : DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100, 12, 31),
                        );
                        if (date != null) {
                          controllers[field.key]!.text = formatDate(date);
                          onChanged(field.key, formatDate(date));
                        }
                      },
              ),
            )
          : decoration,
      validator: validate,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (value) => onChanged(field.key, value),
    );
  }
}
