class PricingQuote {
  const PricingQuote({
    required this.base,
    required this.urgencyPercent,
    required this.urgency,
    required this.preparationMinutes,
    required this.preparation,
    required this.discountPercent,
    required this.discount,
    required this.total,
  });
  final int base,
      urgencyPercent,
      urgency,
      preparationMinutes,
      preparation,
      discountPercent,
      discount,
      total;
  factory PricingQuote.calculate({
    required int base,
    required int urgencyLevel,
    required int preparationMinutes,
    int discountPercent = 0,
  }) {
    if (base <= 0 ||
        urgencyLevel < 1 ||
        urgencyLevel > 3 ||
        preparationMinutes < 0 ||
        discountPercent < 0 ||
        discountPercent > 30) {
      throw ArgumentError('Недопустимые параметры расчёта');
    }
    final urgencyPercent = [0, 20, 50][urgencyLevel - 1];
    final urgency = (base * urgencyPercent / 100).round();
    final preparation = preparationMinutes * 10;
    final subtotal = base + urgency + preparation;
    final discount = (subtotal * discountPercent / 100).round();
    return PricingQuote(
      base: base,
      urgencyPercent: urgencyPercent,
      urgency: urgency,
      preparationMinutes: preparationMinutes,
      preparation: preparation,
      discountPercent: discountPercent,
      discount: discount,
      total: subtotal - discount,
    );
  }
  factory PricingQuote.fromJson(Map<String, dynamic> json) => PricingQuote(
    base: (json['base'] as num).toInt(),
    urgencyPercent: (json['urgencyPercent'] as num).toInt(),
    urgency: (json['urgency'] as num).toInt(),
    preparationMinutes: (json['preparationMinutes'] as num).toInt(),
    preparation: (json['preparation'] as num).toInt(),
    discountPercent: (json['discountPercent'] as num).toInt(),
    discount: (json['discount'] as num).toInt(),
    total: (json['total'] as num).toInt(),
  );
  Map<String, dynamic> toJson() => {
    'base': base,
    'urgencyPercent': urgencyPercent,
    'urgency': urgency,
    'preparationMinutes': preparationMinutes,
    'preparation': preparation,
    'discountPercent': discountPercent,
    'discount': discount,
    'total': total,
  };
}
