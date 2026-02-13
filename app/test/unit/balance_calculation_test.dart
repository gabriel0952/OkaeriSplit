import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BalanceCard summary calculation', () {
    // Reproduces the same logic used in BalanceCard widget
    double totalReceivable(List<BalanceEntity> balances) {
      double sum = 0;
      for (final b in balances) {
        if (b.netBalance > 0) sum += b.netBalance;
      }
      return sum;
    }

    double totalPayable(List<BalanceEntity> balances) {
      double sum = 0;
      for (final b in balances) {
        if (b.netBalance < 0) sum += b.netBalance.abs();
      }
      return sum;
    }

    test('receivable and payable from mixed balances', () {
      final balances = [
        const BalanceEntity(
          userId: 'u1',
          displayName: 'Alice',
          totalPaid: 300,
          totalOwed: 100,
          netBalance: 200,
        ),
        const BalanceEntity(
          userId: 'u2',
          displayName: 'Bob',
          totalPaid: 0,
          totalOwed: 200,
          netBalance: -200,
        ),
      ];

      expect(totalReceivable(balances), 200.0);
      expect(totalPayable(balances), 200.0);
      expect(totalReceivable(balances) - totalPayable(balances), 0.0);
    });

    test('all positive balances', () {
      final balances = [
        const BalanceEntity(
          userId: 'u1',
          displayName: 'Alice',
          totalPaid: 100,
          totalOwed: 0,
          netBalance: 100,
        ),
        const BalanceEntity(
          userId: 'u2',
          displayName: 'Bob',
          totalPaid: 50,
          totalOwed: 0,
          netBalance: 50,
        ),
      ];

      expect(totalReceivable(balances), 150.0);
      expect(totalPayable(balances), 0.0);
    });

    test('all negative balances', () {
      final balances = [
        const BalanceEntity(
          userId: 'u1',
          displayName: 'Alice',
          totalPaid: 0,
          totalOwed: 100,
          netBalance: -100,
        ),
        const BalanceEntity(
          userId: 'u2',
          displayName: 'Bob',
          totalPaid: 0,
          totalOwed: 50,
          netBalance: -50,
        ),
      ];

      expect(totalReceivable(balances), 0.0);
      expect(totalPayable(balances), 150.0);
    });

    test('empty balances', () {
      final balances = <BalanceEntity>[];
      expect(totalReceivable(balances), 0.0);
      expect(totalPayable(balances), 0.0);
    });

    test('zero net balance user contributes to neither', () {
      final balances = [
        const BalanceEntity(
          userId: 'u1',
          displayName: 'Alice',
          totalPaid: 100,
          totalOwed: 100,
          netBalance: 0,
        ),
      ];

      expect(totalReceivable(balances), 0.0);
      expect(totalPayable(balances), 0.0);
    });
  });

  group('BalanceEntity properties', () {
    test('netBalance = totalPaid - totalOwed conceptually', () {
      const balance = BalanceEntity(
        userId: 'u1',
        displayName: 'Alice',
        totalPaid: 500,
        totalOwed: 300,
        netBalance: 200,
      );

      expect(balance.netBalance, 200);
      expect(balance.totalPaid - balance.totalOwed, balance.netBalance);
    });
  });
}
