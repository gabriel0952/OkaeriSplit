import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
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
  final isOnline = ref.watch(isOnlineProvider);
  if (!isOnline) return [];

  final getBalances = ref.watch(getBalancesUseCaseProvider);
  final result = await getBalances(groupId);
  // Return empty list on error instead of throwing — prevents cascade crashes.
  return result.fold((failure) => [], (balances) => balances);
});

final settlementsProvider =
    FutureProvider.family<List<SettlementEntity>, String>((
  ref,
  groupId,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  if (!isOnline) return [];

  final getSettlements = ref.watch(getSettlementsUseCaseProvider);
  final result = await getSettlements(groupId);
  return result.fold((failure) => [], (settlements) => settlements);
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

  // Balance data is server-computed; show empty list when offline.
  final isOnline = ref.watch(isOnlineProvider);
  if (!isOnline) return [];

  final getOverallBalances = ref.watch(getOverallBalancesUseCaseProvider);
  final result = await getOverallBalances(currentUser.id);

  // RPC now returns the group's base currency directly, with exchange rate
  // conversion already applied — no client-side currency fixup needed.
  return result.fold(
    (failure) => [],
    (balances) => balances,
  );
});
