import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/presentation/widgets/split_summary.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final joinedAt = DateTime(2025, 1, 1);
  final members = [
    GroupMemberEntity(
      groupId: 'g1',
      userId: 'u1',
      displayName: 'Alice',
      role: 'member',
      joinedAt: joinedAt,
    ),
    GroupMemberEntity(
      groupId: 'g1',
      userId: 'u2',
      displayName: 'Bob',
      role: 'member',
      joinedAt: joinedAt,
    ),
    GroupMemberEntity(
      groupId: 'g1',
      userId: 'u3',
      displayName: 'Charlie',
      role: 'member',
      joinedAt: joinedAt,
    ),
  ];

  Widget buildWidget(List<ExpenseSplitEntity> splits) {
    return MaterialApp(
      home: Scaffold(
        body: SplitSummary(
          splits: splits,
          members: members,
          currency: 'TWD',
        ),
      ),
    );
  }

  group('SplitSummary', () {
    testWidgets('renders correct number of member rows', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 100,
          splitType: SplitType.equal,
        ),
        const ExpenseSplitEntity(
          id: 's2',
          expenseId: 'e1',
          userId: 'u2',
          amount: 100,
          splitType: SplitType.equal,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsNothing);
    });

    testWidgets('displays amounts correctly', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 150.50,
          splitType: SplitType.equal,
        ),
        const ExpenseSplitEntity(
          id: 's2',
          expenseId: 'e1',
          userId: 'u2',
          amount: 49.50,
          splitType: SplitType.equal,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('\$150.50'), findsOneWidget);
      expect(find.text('\$49.50'), findsOneWidget);
    });

    testWidgets('shows badge for custom ratio splits', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 200,
          splitType: SplitType.customRatio,
        ),
        const ExpenseSplitEntity(
          id: 's2',
          expenseId: 'e1',
          userId: 'u2',
          amount: 100,
          splitType: SplitType.customRatio,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('自訂比例'), findsNWidgets(2));
    });

    testWidgets('shows badge for fixed amount splits', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 60,
          splitType: SplitType.fixedAmount,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('指定金額'), findsOneWidget);
    });

    testWidgets('does not show badge for equal splits', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 100,
          splitType: SplitType.equal,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('自訂比例'), findsNothing);
      expect(find.text('指定金額'), findsNothing);
    });

    testWidgets('shows first letter avatar', (tester) async {
      final splits = [
        const ExpenseSplitEntity(
          id: 's1',
          expenseId: 'e1',
          userId: 'u1',
          amount: 100,
          splitType: SplitType.equal,
        ),
      ];

      await tester.pumpWidget(buildWidget(splits));

      expect(find.text('A'), findsOneWidget);
    });
  });
}
