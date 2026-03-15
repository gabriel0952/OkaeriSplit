import 'dart:math';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/hive_expense_datasource.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/data/pending_expense_repository.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fpdart/fpdart.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  const ExpenseRepositoryImpl(
    this._dataSource,
    this._local,
    this._pendingRepo,
    this._isOnline,
  );
  final SupabaseExpenseDataSource _dataSource;
  final HiveExpenseDataSource _local;
  final PendingExpenseRepository _pendingRepo;
  final bool _isOnline;

  @override
  Future<AppResult<List<ExpenseEntity>>> getExpenses(String groupId) async {
    List<ExpenseEntity> synced;
    if (!_isOnline) {
      synced = _local.getExpenses(groupId);
    } else {
      try {
        final fetched = await _dataSource.getExpenses(groupId);
        await _local.saveExpenses(groupId, fetched);
        synced = fetched;
      } catch (_) {
        synced = _local.getExpenses(groupId);
      }
    }

    // Prepend any locally-queued (offline) expenses so they appear in the list
    // before they have been synced to the server.
    final pending = _pendingRepo
        .getAll()
        .where((p) => p.groupId == groupId)
        .map(_pendingToEntity)
        .toList();

    return Right([...pending, ...synced]);
  }

  static ExpenseEntity _pendingToEntity(PendingExpenseDto p) => ExpenseEntity(
        id: p.localId,
        groupId: p.groupId,
        paidBy: p.paidBy,
        amount: p.amount,
        currency: p.currency,
        category: p.category,
        description: p.description,
        note: p.note,
        expenseDate: p.expenseDate,
        createdAt: p.pendingAt,
        updatedAt: p.pendingAt,
        splits: p.splits
            .map(
              (s) => ExpenseSplitEntity(
                id: '${p.localId}_${s['user_id']}',
                expenseId: p.localId,
                userId: s['user_id'] as String,
                amount: (s['amount'] as num).toDouble(),
                splitType: SplitType.values.firstWhere(
                  (e) => e.name == (s['split_type'] as String),
                  orElse: () => SplitType.equal,
                ),
              ),
            )
            .toList(),
        isPending: true,
      );

  @override
  Future<AppResult<ExpenseEntity>> getExpenseDetail(String expenseId) async {
    try {
      final expense = await _dataSource.getExpenseDetail(expenseId);
      return Right(expense);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<String>> createExpense({
    required String groupId,
    required String paidBy,
    required double amount,
    required String currency,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    required List<Map<String, dynamic>> splits,
  }) async {
    if (!_isOnline) {
      final dto = PendingExpenseDto(
        localId: _uuid(),
        groupId: groupId,
        paidBy: paidBy,
        amount: amount,
        currency: currency,
        category: category,
        description: description,
        note: note,
        expenseDate: expenseDate,
        splits: splits,
        pendingAt: DateTime.now(),
      );
      await _pendingRepo.add(dto);
      return Right(dto.localId);
    }
    try {
      final expenseId = await _dataSource.createExpense(
        groupId: groupId,
        paidBy: paidBy,
        amount: amount,
        currency: currency,
        category: category,
        description: description,
        note: note,
        expenseDate: expenseDate,
        splits: splits,
      );
      return Right(expenseId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> updateExpense({
    required String expenseId,
    required String paidBy,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    List<Map<String, dynamic>>? splits,
  }) async {
    try {
      await _dataSource.updateExpense(
        expenseId: expenseId,
        paidBy: paidBy,
        amount: amount,
        category: category,
        description: description,
        note: note,
        expenseDate: expenseDate,
        splits: splits,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> deleteExpense(String expenseId) async {
    try {
      await _dataSource.deleteExpense(expenseId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  static String _uuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
