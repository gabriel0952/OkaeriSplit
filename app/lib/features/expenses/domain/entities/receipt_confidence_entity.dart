enum ReceiptConfidenceLevel { high, medium, low }

class ReceiptConfidenceEntity {
  const ReceiptConfidenceEntity({
    required this.score,
    required this.level,
    this.reasons = const [],
  });

  final double score;
  final ReceiptConfidenceLevel level;
  final List<String> reasons;
}
