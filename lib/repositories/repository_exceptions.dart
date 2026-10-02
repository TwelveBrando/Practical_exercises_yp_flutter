class FieldValidationException implements Exception {
  const FieldValidationException(this.errors);
  final Map<String, String> errors;
}

class RelatedRecordsException implements Exception {
  const RelatedRecordsException(this.counts);
  final Map<String, int> counts;
  @override
  String toString() =>
      'Удаление невозможно: связанные записи — ${counts.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}. Сначала измените или удалите эти связи. Учитываются также записи в корзине.';
}
