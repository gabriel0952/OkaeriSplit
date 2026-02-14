import 'package:app/features/settlements/domain/entities/settlement_entity.dart';

/// Computes the minimum set of transfers to settle all debts.
abstract final class DebtSimplifier {
  static const _threshold = 0.005;

  /// Given a list of balances (netBalance per user), returns the minimal
  /// set of transfers to settle all debts using a greedy algorithm.
  static List<SimplifiedDebtEntity> simplify(List<BalanceEntity> balances) {
    // Separate into debtors (negative balance) and creditors (positive balance)
    final debtors = <_Entry>[]; // people who owe money
    final creditors = <_Entry>[]; // people who are owed money

    for (final b in balances) {
      if (b.netBalance < -_threshold) {
        debtors.add(_Entry(
          userId: b.userId,
          displayName: b.displayName,
          avatarUrl: b.avatarUrl,
          amount: b.netBalance.abs(),
        ));
      } else if (b.netBalance > _threshold) {
        creditors.add(_Entry(
          userId: b.userId,
          displayName: b.displayName,
          avatarUrl: b.avatarUrl,
          amount: b.netBalance,
        ));
      }
    }

    // Sort descending by amount for greedy matching
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final results = <SimplifiedDebtEntity>[];

    int di = 0, ci = 0;
    while (di < debtors.length && ci < creditors.length) {
      final debtor = debtors[di];
      final creditor = creditors[ci];
      final transfer = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      if (transfer > _threshold) {
        results.add(SimplifiedDebtEntity(
          fromUserId: debtor.userId,
          fromDisplayName: debtor.displayName,
          fromAvatarUrl: debtor.avatarUrl,
          toUserId: creditor.userId,
          toDisplayName: creditor.displayName,
          toAvatarUrl: creditor.avatarUrl,
          amount: (transfer * 100).round() / 100.0,
        ));
      }

      debtor.amount -= transfer;
      creditor.amount -= transfer;

      if (debtor.amount < _threshold) di++;
      if (creditor.amount < _threshold) ci++;
    }

    return results;
  }
}

class _Entry {
  _Entry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.amount,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  double amount;
}
