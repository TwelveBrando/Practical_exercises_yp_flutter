class Validators {
  static String? text(Object? value, {int min = 1, int max = 120}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'Обязательное поле';
    if (text.length < min) return 'Минимальная длина — $min символов';
    if (text.length > max) return 'Максимум $max символов';
    return null;
  }

  static String? email(Object? value) {
    final requiredError = text(value, max: 120);
    if (requiredError != null) return requiredError;
    if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(value.toString().trim())) {
      return 'Введите корректный адрес электронной почты';
    }
    return null;
  }

  static String? integer(Object? value, {int min = 0, int max = 1000000}) {
    if ((value?.toString() ?? '').trim().isEmpty) return 'Обязательное поле';
    final number = int.tryParse(value.toString().trim());
    if (number == null) return 'Введите целое число';
    if (number < min || number > max) return 'Допустимо от $min до $max';
    return null;
  }

  static String? date(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'Обязательное поле';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Формат: ГГГГ-ММ-ДД';
    }
    final date = DateTime.tryParse(text);
    if (date == null ||
        date.year < 1900 ||
        date.year > 2100 ||
        date.toIso8601String().substring(0, 10) != text) {
      return 'Несуществующая дата или год вне 1900–2100';
    }
    return null;
  }

  static String? phone(Object? value) {
    final error = text(value, max: 25);
    if (error != null) return error;
    if (!RegExp(r'^\+?[0-9 ()-]{10,25}$').hasMatch(value.toString()) ||
        value.toString().replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Введите телефон, например +7 900 123-45-67';
    }
    return null;
  }

  static String? identifier(Object? value, String prefix) {
    if ((value?.toString() ?? '').isEmpty) return 'Обязательное поле';
    if (!RegExp(
      '^$prefix-'
      r'[0-9]{4,8}$',
    ).hasMatch(value.toString().trim())) {
      return 'Формат: $prefix-0001 (4–8 цифр)';
    }
    return null;
  }

  static String? selection(Object? value, Iterable<Object> allowed) =>
      value == null
      ? 'Выберите значение'
      : allowed.contains(value)
      ? null
      : 'Выбранная запись недоступна';

  static String? multiple(Object? value, Iterable<Object> allowed) {
    if (value is! List || value.isEmpty) return 'Выберите хотя бы одну запись';
    if (value.any((id) => !allowed.contains(id))) {
      return 'Некоторые записи недоступны, измените выбор';
    }
    return null;
  }
}
