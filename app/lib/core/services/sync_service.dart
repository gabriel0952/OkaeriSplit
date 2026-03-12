import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/data/pending_expense_repository.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncService {
  SyncService(this._pendingRepo, this._dataSource, this._ref);

  final PendingExpenseRepository _pendingRepo;
  final SupabaseExpenseDataSource _dataSource;
  final Ref _ref;

  bool _isFlushing = false;

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;

    final pending = _pendingRepo.getAll();
    final affectedGroups = <String>{};

    for (final item in pending) {
      try {
        await _dataSource.createExpense(
          groupId: item.groupId,
          paidBy: item.paidBy,
          amount: item.amount,
          currency: item.currency,
          category: item.category,
          description: item.description,
          note: item.note,
          expenseDate: item.expenseDate,
          splits: item.splits,
        );
        await _pendingRepo.remove(item.localId);
        affectedGroups.add(item.groupId);
      } catch (_) {
        // Keep the item; will retry on next flush.
      }
    }

    for (final groupId in affectedGroups) {
      _ref.invalidate(expensesProvider(groupId));
    }
    if (affectedGroups.isNotEmpty) {
      _ref.invalidate(pendingCountProvider);
    }

    _isFlushing = false;
  }
}
