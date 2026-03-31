enum GeminiTaxType { included, excluded, exempt }

enum GeminiSuggestedCategory {
  dining('餐飲'),
  transport('交通'),
  shopping('購物'),
  accommodation('住宿'),
  entertainment('娛樂'),
  medical('醫藥'),
  other('其他');

  const GeminiSuggestedCategory(this.label);
  final String label;
}

class GeminiScanExtras {
  const GeminiScanExtras({
    this.merchant,
    this.date,
    this.currency,
    this.taxAmount,
    this.taxType,
    this.suggestedCategory,
  });

  final String? merchant;
  final DateTime? date;
  final String? currency;
  final double? taxAmount;
  final GeminiTaxType? taxType;
  final GeminiSuggestedCategory? suggestedCategory;
}
