import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:app/features/expenses/presentation/widgets/split_summary.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  final String groupId;
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    // Keep the realtime subscription alive (online only).
    if (isOnline) {
      ref.listen(realtimeExpensesProvider(groupId), (prev, next) {});
    }

    // expenseDetailLiveProvider watches expensesProvider(groupId) internally.
    // When the realtime callback invalidates expensesProvider, Riverpod's
    // dependency graph propagates the invalidation here automatically.
    final liveKey = (groupId: groupId, expenseId: expenseId);
    final expenseAsync = ref.watch(expenseDetailLiveProvider(liveKey));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final customCategories =
        ref.watch(groupCategoriesProvider(groupId)).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('消費詳情')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: expenseAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(expenseDetailLiveProvider(liveKey)),
        ),
        data: (expense) {
          final members = membersAsync.valueOrNull ?? [];
          final memberMap = {for (final m in members) m.userId: m.displayName};
          final isOwner = currentUser?.id == expense.paidBy;
          final isMember = members.any((m) => m.userId == currentUser?.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Amount
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '\$${expense.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense.currency,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow(context, '描述', expense.description),
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const Divider(),
                        _infoRow(context, '備註', expense.note!),
                      ],
                      const Divider(),
                      _infoRow(
                        context,
                        '分類',
                        categoryLabel(expense.category, customCategories),
                      ),
                      const Divider(),
                      _infoRow(
                        context,
                        '付款人',
                        memberMap[expense.paidBy] ?? expense.paidBy,
                      ),
                      const Divider(),
                      _infoRow(
                        context,
                        '日期',
                        DateFormat('yyyy/MM/dd').format(expense.expenseDate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attachments
              if (expense.attachmentUrls.isNotEmpty) ...[
                Text(
                  '收據/照片',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: expense.attachmentUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = expense.attachmentUrls[index];
                      return GestureDetector(
                        onTap: () => _showFullImage(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Split details
              Text(
                '分帳明細',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SplitSummary(
                    splits: expense.splits,
                    members: members,
                    currency: expense.currency,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Edit button: all group members can edit
              if (isMember) ...[
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/groups/$groupId/expenses/$expenseId/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯'),
                ),
                const SizedBox(height: 8),
              ],

              // Delete button: only paidBy
              if (isOwner)
                OutlinedButton.icon(
                  onPressed: () => _handleDelete(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('刪除'),
                ),
            ],
          );
        },
      )),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這筆消費嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteExpense = ref.read(deleteExpenseUseCaseProvider);
    final result = await deleteExpense(expenseId);

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(expensesProvider(groupId));
        context.pop();
      },
    );
  }
}
