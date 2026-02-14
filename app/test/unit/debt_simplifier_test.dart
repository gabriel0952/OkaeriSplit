import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/utils/debt_simplifier.dart';
import 'package:flutter_test/flutter_test.dart';

BalanceEntity _balance(String id, String name, double net) {
  return BalanceEntity(
    userId: id,
    displayName: name,
    totalPaid: 0,
    totalOwed: 0,
    netBalance: net,
  );
}

void main() {
  group('DebtSimplifier', () {
    test('empty input returns empty result', () {
      expect(DebtSimplifier.simplify([]), isEmpty);
    });

    test('all zero balances returns empty result', () {
      final balances = [
        _balance('a', 'Alice', 0),
        _balance('b', 'Bob', 0),
      ];
      expect(DebtSimplifier.simplify(balances), isEmpty);
    });

    test('two people: one owes the other → 1 transfer', () {
      final balances = [
        _balance('a', 'Alice', 100),
        _balance('b', 'Bob', -100),
      ];
      final result = DebtSimplifier.simplify(balances);

      expect(result, hasLength(1));
      expect(result[0].fromUserId, 'b');
      expect(result[0].toUserId, 'a');
      expect(result[0].amount, 100);
    });

    test('one creditor + multiple debtors', () {
      final balances = [
        _balance('a', 'Alice', 300),
        _balance('b', 'Bob', -100),
        _balance('c', 'Carol', -200),
      ];
      final result = DebtSimplifier.simplify(balances);

      // Should have 2 transfers, both to Alice
      expect(result, hasLength(2));

      final totalToAlice = result
          .where((d) => d.toUserId == 'a')
          .fold(0.0, (sum, d) => sum + d.amount);
      expect(totalToAlice, 300);
    });

    test('multiple creditors + multiple debtors → transfers ≤ N-1', () {
      final balances = [
        _balance('a', 'Alice', 200),
        _balance('b', 'Bob', 100),
        _balance('c', 'Carol', -150),
        _balance('d', 'Dave', -150),
      ];
      final result = DebtSimplifier.simplify(balances);

      // N=4 people, so at most 3 transfers
      expect(result.length, lessThanOrEqualTo(3));

      // Total from debtors should equal total to creditors
      final totalFrom = result.fold(0.0, (sum, d) => sum + d.amount);
      expect(totalFrom, closeTo(300, 0.01));
    });

    test('floating-point noise (±0.001) is filtered out', () {
      final balances = [
        _balance('a', 'Alice', 0.001),
        _balance('b', 'Bob', -0.001),
      ];
      final result = DebtSimplifier.simplify(balances);
      expect(result, isEmpty);
    });

    test('amounts are rounded to 2 decimal places', () {
      final balances = [
        _balance('a', 'Alice', 33.33),
        _balance('b', 'Bob', -33.33),
      ];
      final result = DebtSimplifier.simplify(balances);

      expect(result, hasLength(1));
      final amountStr = result[0].amount.toStringAsFixed(2);
      expect(amountStr, '33.33');
    });

    test('preserves display names and avatar urls', () {
      final balances = [
        BalanceEntity(
          userId: 'a',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/alice.png',
          totalPaid: 0,
          totalOwed: 0,
          netBalance: 50,
        ),
        BalanceEntity(
          userId: 'b',
          displayName: 'Bob',
          avatarUrl: 'https://example.com/bob.png',
          totalPaid: 0,
          totalOwed: 0,
          netBalance: -50,
        ),
      ];
      final result = DebtSimplifier.simplify(balances);

      expect(result[0].fromDisplayName, 'Bob');
      expect(result[0].fromAvatarUrl, 'https://example.com/bob.png');
      expect(result[0].toDisplayName, 'Alice');
      expect(result[0].toAvatarUrl, 'https://example.com/alice.png');
    });
  });
}
