int readInt(Object? value, [int fallback = 0]) {
  if (value is num && value.isFinite) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String readString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
DateTime readDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2026, 1, 1);
DateTime? readOptionalDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '');
List<int> readIds(Object? value) {
  if (value is! List) return const [];
  return value.map(readInt).where((id) => id > 0).toSet().toList();
}

Map<String, dynamic> readMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
