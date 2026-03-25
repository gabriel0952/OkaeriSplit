import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/domain/utils/debt_simplifier.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrossGroupDebtItem {
  const CrossGroupDebtItem({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.counterpartUserId,
    required this.counterpartDisplayName,
    this.counterpartAvatarUrl,
    required this.amount,
    required this.iOwe,
  });

  final String groupId;
  final String groupName;
  final String currency;
  final String counterpartUserId;
  final String counterpartDisplayName;
  final String? counterpartAvatarUrl;
  final double amount;

  /// true = I owe the counterpart, false = they owe me
  final bool iOwe;
}

/// Aggregates simplified debts for the current user across all ACTIVE groups.
/// Items are ordered by group creation time (ascending).
final crossGroupDebtsProvider =
    FutureProvider<List<CrossGroupDebtItem>>((ref) async {
  final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;
  if (currentUserId == null) return [];

  final groups = await ref.watch(groupsProvider.future);

  // Only active groups, sorted by creation time ascending.
  final activeGroups = groups.where((g) => g.status == 'active').toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final items = <CrossGroupDebtItem>[];

  for (final group in activeGroups) {
    try {
      final balances = await ref.watch(balancesProvider(group.id).future);
      final simplified = DebtSimplifier.simplify(balances);
      for (final debt in simplified) {
        if (debt.fromUserId == currentUserId) {
          items.add(CrossGroupDebtItem(
            groupId: group.id,
            groupName: group.name,
            currency: group.currency,
            counterpartUserId: debt.toUserId,
            counterpartDisplayName: debt.toDisplayName,
            counterpartAvatarUrl: debt.toAvatarUrl,
            amount: debt.amount,
            iOwe: true,
          ));
        } else if (debt.toUserId == currentUserId) {
          items.add(CrossGroupDebtItem(
            groupId: group.id,
            groupName: group.name,
            currency: group.currency,
            counterpartUserId: debt.fromUserId,
            counterpartDisplayName: debt.fromDisplayName,
            counterpartAvatarUrl: debt.fromAvatarUrl,
            amount: debt.amount,
            iOwe: false,
          ));
        }
      }
    } catch (_) {
      // Skip groups whose balances can't be loaded (e.g. offline).
    }
  }

  return items;
});
