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

class MockHiveExpenseDataSource extends Mock implements HiveExpenseDataSource {}

class MockPendingExpenseRepository extends Mock
    implements PendingExpenseRepository {}

void main() {
  late MockSupabaseExpenseDataSource mockDataSource;
  late MockHiveExpenseDataSource mockHive;
  late MockPendingExpenseRepository mockPending;
  late ExpenseRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      PendingExpenseDto(
        localId: 'local-1',
        groupId: 'group-1',
        paidBy: 'user-1',
        amount: 0,
        currency: 'TWD',
        category: 'food',
        description: 'fallback',
        expenseDate: DateTime(2025, 1, 1),
        splits: const [],
        items: const [],
        pendingAt: DateTime(2025, 1, 1),
      ),
    );
  });

  setUp(() {
    mockDataSource = MockSupabaseExpenseDataSource();
    mockHive = MockHiveExpenseDataSource();
    mockPending = MockPendingExpenseRepository();
    when(() => mockPending.getAll()).thenReturn(const []);
    when(() => mockHive.getExpenses(any())).thenReturn(const []);
    when(() => mockHive.saveExpenses(any(), any())).thenAnswer((_) async {});
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
      when(
        () => mockDataSource.getExpenses('group-1'),
      ).thenAnswer((_) async => [tExpense]);
      final result = await repository.getExpenses('group-1');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be Right'), (expenses) {
        expect(expenses.length, 1);
        expect(expenses.first.id, 'exp-1');
      });
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

    test('falls back to cached expenses on exception', () async {
      when(
        () => mockDataSource.getExpenses('group-1'),
      ).thenThrow(Exception('network error'));
      when(() => mockHive.getExpenses('group-1')).thenReturn([tExpense]);

      final result = await repository.getExpenses('group-1');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be Right'), (expenses) {
        expect(expenses, hasLength(1));
        expect(expenses.first.id, 'exp-1');
      });
    });
  });

  group('getExpenseDetail', () {
    test('returns Right with expense on success', () async {
      when(
        () => mockDataSource.getExpenseDetail('exp-1'),
      ).thenAnswer((_) async => tExpense);

      final result = await repository.getExpenseDetail('exp-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('should be Right'),
        (expense) => expect(expense.description, '午餐'),
      );
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.getExpenseDetail('exp-1'),
      ).thenThrow(Exception('not found'));

      final result = await repository.getExpenseDetail('exp-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('createExpense', () {
    test('forwards itemized items to datasource when online', () async {
      final expenseDate = DateTime(2025, 1, 2);
      final items = [
        {
          'name': '可樂',
          'amount': 40.0,
          'shared_by_user_ids': ['user-1', 'user-2'],
        },
      ];
      when(
        () => mockDataSource.createExpense(
          groupId: 'group-1',
          paidBy: 'user-1',
          amount: 40,
          currency: 'TWD',
          category: 'food',
          description: '點餐',
          note: null,
          expenseDate: expenseDate,
          splits: const [
            {'user_id': 'user-1', 'amount': 20.0, 'split_type': 'itemized'},
            {'user_id': 'user-2', 'amount': 20.0, 'split_type': 'itemized'},
          ],
          items: items,
        ),
      ).thenAnswer((_) async => 'exp-2');

      final result = await repository.createExpense(
        groupId: 'group-1',
        paidBy: 'user-1',
        amount: 40,
        currency: 'TWD',
        category: 'food',
        description: '點餐',
        expenseDate: expenseDate,
        splits: const [
          {'user_id': 'user-1', 'amount': 20.0, 'split_type': 'itemized'},
          {'user_id': 'user-2', 'amount': 20.0, 'split_type': 'itemized'},
        ],
        items: items,
      );

      expect(result.isRight(), isTrue);
      verify(
        () => mockDataSource.createExpense(
          groupId: 'group-1',
          paidBy: 'user-1',
          amount: 40,
          currency: 'TWD',
          category: 'food',
          description: '點餐',
          note: null,
          expenseDate: expenseDate,
          splits: const [
            {'user_id': 'user-1', 'amount': 20.0, 'split_type': 'itemized'},
            {'user_id': 'user-2', 'amount': 20.0, 'split_type': 'itemized'},
          ],
          items: items,
        ),
      ).called(1);
    });

    test('stores itemized items in pending queue when offline', () async {
      final offlineRepo = ExpenseRepositoryImpl(
        mockDataSource,
        mockHive,
        mockPending,
        false,
      );
      when(() => mockPending.add(any())).thenAnswer((_) async {});

      final result = await offlineRepo.createExpense(
        groupId: 'group-1',
        paidBy: 'user-1',
        amount: 90,
        currency: 'TWD',
        category: 'food',
        description: '晚餐',
        expenseDate: DateTime(2025, 1, 2),
        splits: const [
          {'user_id': 'user-1', 'amount': 30.0, 'split_type': 'itemized'},
          {'user_id': 'user-2', 'amount': 60.0, 'split_type': 'itemized'},
        ],
        items: const [
          {
            'name': '拉麵',
            'amount': 90.0,
            'shared_by_user_ids': ['user-1', 'user-2'],
          },
        ],
      );

      expect(result.isRight(), isTrue);
      final captured =
          verify(() => mockPending.add(captureAny())).captured.single
              as PendingExpenseDto;
      expect(captured.items, isNotEmpty);
      expect(captured.items.first['name'], '拉麵');
    });
  });

  group('deleteExpense', () {
    test('returns Right(null) on success', () async {
      when(
        () => mockDataSource.deleteExpense('exp-1'),
      ).thenAnswer((_) async {});

      final result = await repository.deleteExpense('exp-1');

      expect(result.isRight(), isTrue);
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.deleteExpense('exp-1'),
      ).thenThrow(Exception('delete failed'));

      final result = await repository.deleteExpense('exp-1');

      expect(result.isLeft(), isTrue);
    });
  });
}
