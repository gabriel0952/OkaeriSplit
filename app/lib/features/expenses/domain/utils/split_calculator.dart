abstract final class SplitCalculator {
  /// Equal split with remainder going to the first person.
  static List<double> calculateEqualSplits(double total, int count) {
    if (count <= 0 || total <= 0) return [];

    final totalCents = (total * 100).round();
    final baseCents = totalCents ~/ count;
    final remainderCents = totalCents - baseCents * count;

    return List.generate(count, (i) {
      final cents = i < remainderCents ? baseCents + 1 : baseCents;
      return cents / 100.0;
    });
  }

  /// Custom ratio split. Returns a map of userId → amount.
  /// Remainder cents are distributed one-by-one to earliest entries.
  static Map<String, double> calculateRatioSplits(
    double total,
    Map<String, int> ratios,
  ) {
    if (ratios.isEmpty || total <= 0) return {};

    final totalRatio = ratios.values.fold(0, (a, b) => a + b);
    if (totalRatio <= 0) return {};

    final totalCents = (total * 100).round();
    final result = <String, double>{};
    int distributed = 0;

    final entries = ratios.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i == entries.length - 1) {
        // Last person gets the remainder to avoid rounding drift
        result[entry.key] = (totalCents - distributed) / 100.0;
      } else {
        final cents = (totalCents * entry.value / totalRatio).round();
        result[entry.key] = cents / 100.0;
        distributed += cents;
      }
    }

    return result;
  }

  /// Validate that fixed amounts sum to the total (within 0.01 tolerance).
  static bool validateFixedAmounts(
    double total,
    Map<String, double> amounts,
  ) {
    if (amounts.isEmpty) return false;
    final sum = amounts.values.fold(0.0, (a, b) => a + b);
    return (sum - total).abs() < 0.01;
  }

  /// Returns the difference between total and the sum of fixed amounts.
  static double fixedAmountDifference(
    double total,
    Map<String, double> amounts,
  ) {
    final sum = amounts.values.fold(0.0, (a, b) => a + b);
    return total - sum;
  }
}
