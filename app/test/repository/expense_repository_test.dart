import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/hive_expense_datasource.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/data/pending_expense_repository.dart';
import 'package:app/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseExpenseDataSource extends Mock
    implements SupabaseExpenseDataSource {}

class MockHiveExpenseDataSource extends Mock
    implements HiveExpenseDataSource {}

class MockPendingExpenseRepository extends Mock
    implements PendingExpenseRepository {}

void main() {
  late MockSupabaseExpenseDataSource mockDataSource;
  late MockHiveExpenseDataSource mockHive;
  late MockPendingExpenseRepository mockPending;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockSupabaseExpenseDataSource();
    mockHive = MockHiveExpenseDataSource();
    mockPending = MockPendingExpenseRepository();
    // isOnline = true for most tests
    repository = ExpenseRepositoryImpl(
      mockDataSource,
      mockHive,
      mockPending,
      true,
    );
  });

  final tExpense = ExpenseEntity(
    id: 'exp-1',
    groupId: 'group-1',
    paidBy: 'user-1',
    amount: 300,
    currency: 'TWD',
    category: 'food',
    description: '午餐',
    expenseDate: DateTime(2025, 1, 1),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    splits: const [
      ExpenseSplitEntity(
        id: 's1',
        expenseId: 'exp-1',
        userId: 'user-1',
        amount: 150,
        splitType: SplitType.equal,
      ),
      ExpenseSplitEntity(
        id: 's2',
        expenseId: 'exp-1',
        userId: 'user-2',
        amount: 150,
        splitType: SplitType.equal,
      ),
    ],
  );

  group('getExpenses', () {
    test('returns Right with expenses on success (online)', () async {
      when(() => mockDataSource.getExpenses('group-1'))
          .thenAnswer((_) async => [tExpense]);
      when(() => mockHive.saveExpenses('group-1', any()))
          .thenAnswer((_) async {});

      final result = await repository.getExpenses('group-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('should be Right'),
        (expenses) {
          expect(expenses.length, 1);
          expect(expenses.first.id, 'exp-1');
        },
      );
    });

    test('returns cache when offline', () async {
      final offlineRepo = ExpenseRepositoryImpl(
        mockDataSource,
        mockHive,
        mockPending,
        false, // offline
      );
      when(() => mockHive.getExpenses('group-1')).thenReturn([tExpense]);

      final result = await offlineRepo.getExpenses('group-1');

      expect(result.isRight(), isTrue);
      verifyNever(() => mockDataSource.getExpenses(any()));
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getExpenses('group-1'))
          .thenThrow(Exception('network error'));

      final result = await repository.getExpenses('group-1');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('should be Left'),
      );
    });
  });

  group('getExpenseDetail', () {
    test('returns Right with expense on success', () async {
      when(() => mockDataSource.getExpenseDetail('exp-1'))
          .thenAnswer((_) async => tExpense);

      final result = await repository.getExpenseDetail('exp-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('should be Right'),
        (expense) => expect(expense.description, '午餐'),
      );
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getExpenseDetail('exp-1'))
          .thenThrow(Exception('not found'));

      final result = await repository.getExpenseDetail('exp-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('deleteExpense', () {
    test('returns Right(null) on success', () async {
      when(() => mockDataSource.deleteExpense('exp-1'))
          .thenAnswer((_) async {});

      final result = await repository.deleteExpense('exp-1');

      expect(result.isRight(), isTrue);
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.deleteExpense('exp-1'))
          .thenThrow(Exception('delete failed'));

      final result = await repository.deleteExpense('exp-1');

      expect(result.isLeft(), isTrue);
    });
  });
}
