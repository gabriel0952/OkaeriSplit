import 'package:app/features/expenses/domain/utils/split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplitCalculator.calculateEqualSplits', () {
    test('divides evenly when no remainder', () {
      final result = SplitCalculator.calculateEqualSplits(300, 3);
      expect(result, [100.0, 100.0, 100.0]);
    });

    test('distributes remainder cents to first members', () {
      final result = SplitCalculator.calculateEqualSplits(100, 3);
      // 100 / 3 = 33.33 each, remainder 1 cent → first person gets extra
      expect(result.length, 3);
      expect(result.reduce((a, b) => a + b), closeTo(100.0, 0.01));
      expect(result[0], 33.34);
      expect(result[1], 33.33);
      expect(result[2], 33.33);
    });

    test('single person gets full amount', () {
      final result = SplitCalculator.calculateEqualSplits(500, 1);
      expect(result, [500.0]);
    });

    test('returns empty list for zero count', () {
      expect(SplitCalculator.calculateEqualSplits(100, 0), isEmpty);
    });

    test('returns empty list for zero amount', () {
      expect(SplitCalculator.calculateEqualSplits(0, 3), isEmpty);
    });

    test('returns empty list for negative values', () {
      expect(SplitCalculator.calculateEqualSplits(-10, 3), isEmpty);
      expect(SplitCalculator.calculateEqualSplits(100, -1), isEmpty);
    });

    test('handles two-way split with remainder', () {
      final result = SplitCalculator.calculateEqualSplits(10.01, 2);
      expect(result.length, 2);
      expect(result.reduce((a, b) => a + b), closeTo(10.01, 0.01));
    });
  });

  group('SplitCalculator.calculateRatioSplits', () {
    test('splits 2:1:1 correctly', () {
      final result = SplitCalculator.calculateRatioSplits(400, {
        'a': 2,
        'b': 1,
        'c': 1,
      });
      expect(result['a'], 200.0);
      expect(result['b'], 100.0);
      expect(result['c'], 100.0);
    });

    test('splits with remainder — last person gets remainder', () {
      final result = SplitCalculator.calculateRatioSplits(100, {
        'a': 1,
        'b': 1,
        'c': 1,
      });
      final total = result.values.reduce((a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
    });

    test('returns empty map for zero amount', () {
      expect(SplitCalculator.calculateRatioSplits(0, {'a': 1}), isEmpty);
    });

    test('returns empty map for empty ratios', () {
      expect(SplitCalculator.calculateRatioSplits(100, {}), isEmpty);
    });

    test('handles single person ratio', () {
      final result = SplitCalculator.calculateRatioSplits(250, {'a': 3});
      expect(result['a'], 250.0);
    });

    test('handles uneven ratio like 3:2:1', () {
      final result = SplitCalculator.calculateRatioSplits(600, {
        'a': 3,
        'b': 2,
        'c': 1,
      });
      expect(result['a'], 300.0);
      expect(result['b'], 200.0);
      expect(result['c'], 100.0);
    });
  });

  group('SplitCalculator.validateFixedAmounts', () {
    test('valid when amounts sum to total', () {
      expect(
        SplitCalculator.validateFixedAmounts(100, {'a': 60.0, 'b': 40.0}),
        isTrue,
      );
    });

    test('valid within tolerance', () {
      expect(
        SplitCalculator.validateFixedAmounts(100, {'a': 60.005, 'b': 40.0}),
        isTrue,
      );
    });

    test('invalid when sum is too low', () {
      expect(
        SplitCalculator.validateFixedAmounts(100, {'a': 50.0, 'b': 40.0}),
        isFalse,
      );
    });

    test('invalid when sum is too high', () {
      expect(
        SplitCalculator.validateFixedAmounts(100, {'a': 60.0, 'b': 50.0}),
        isFalse,
      );
    });

    test('invalid for empty amounts', () {
      expect(SplitCalculator.validateFixedAmounts(100, {}), isFalse);
    });
  });

  group('SplitCalculator.fixedAmountDifference', () {
    test('returns 0 when perfectly matched', () {
      final diff = SplitCalculator.fixedAmountDifference(
        100,
        {'a': 60.0, 'b': 40.0},
      );
      expect(diff, closeTo(0, 0.01));
    });

    test('returns positive when under-allocated', () {
      final diff = SplitCalculator.fixedAmountDifference(
        100,
        {'a': 30.0, 'b': 40.0},
      );
      expect(diff, closeTo(30.0, 0.01));
    });

    test('returns negative when over-allocated', () {
      final diff = SplitCalculator.fixedAmountDifference(
        100,
        {'a': 70.0, 'b': 50.0},
      );
      expect(diff, closeTo(-20.0, 0.01));
    });
  });
}
