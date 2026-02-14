import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/data/datasources/supabase_settlement_datasource.dart';
import 'package:app/features/settlements/data/repositories/settlement_repository_impl.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';
import 'package:app/features/settlements/domain/usecases/get_balances.dart';
import 'package:app/features/settlements/domain/usecases/get_overall_balances.dart';
import 'package:app/features/settlements/domain/usecases/get_settlements.dart';
import 'package:app/features/settlements/domain/usecases/mark_settled.dart';
import 'package:app/features/settlements/domain/utils/debt_simplifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final supabaseSettlementDataSourceProvider =
    Provider<SupabaseSettlementDataSource>((ref) {
  return SupabaseSettlementDataSource(ref.watch(supabaseClientProvider));
});

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepositoryImpl(
    ref.watch(supabaseSettlementDataSourceProvider),
  );
});

// Use cases
final getBalancesUseCaseProvider = Provider<GetBalances>((ref) {
  return GetBalances(ref.watch(settlementRepositoryProvider));
});

final getOverallBalancesUseCaseProvider = Provider<GetOverallBalances>((ref) {
  return GetOverallBalances(ref.watch(settlementRepositoryProvider));
});

final getSettlementsUseCaseProvider = Provider<GetSettlements>((ref) {
  return GetSettlements(ref.watch(settlementRepositoryProvider));
});

final markSettledUseCaseProvider = Provider<MarkSettled>((ref) {
  return MarkSettled(ref.watch(settlementRepositoryProvider));
});

// Presentation providers
final balancesProvider =
    FutureProvider.family<List<BalanceEntity>, String>((ref, groupId) async {
  final getBalances = ref.watch(getBalancesUseCaseProvider);
  final result = await getBalances(groupId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (balances) => balances,
  );
});

final settlementsProvider =
    FutureProvider.family<List<SettlementEntity>, String>((
  ref,
  groupId,
) async {
  final getSettlements = ref.watch(getSettlementsUseCaseProvider);
  final result = await getSettlements(groupId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (settlements) => settlements,
  );
});

final simplifiedDebtsProvider =
    Provider.family<List<SimplifiedDebtEntity>, String>((ref, groupId) {
  final balancesAsync = ref.watch(balancesProvider(groupId));
  return balancesAsync.whenOrNull(data: (b) => DebtSimplifier.simplify(b)) ??
      [];
});

final overallBalancesProvider =
    FutureProvider<List<OverallBalanceEntity>>((ref) async {
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  if (currentUser == null) return [];

  final getOverallBalances = ref.watch(getOverallBalancesUseCaseProvider);
  final result = await getOverallBalances(currentUser.id);

  final groups = ref.watch(groupsProvider).valueOrNull ?? [];
  final currencyMap = {for (final g in groups) g.id: g.currency};

  return result.fold(
    (failure) => throw Exception(failure.message),
    (balances) => balances.map((b) {
      if (b.currency != 'TWD' || !currencyMap.containsKey(b.groupId)) return b;
      return OverallBalanceEntity(
        groupId: b.groupId,
        groupName: b.groupName,
        netBalance: b.netBalance,
        currency: currencyMap[b.groupId] ?? b.currency,
      );
    }).toList(),
  );
});
