import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/core/widgets/user_avatar.dart';
import 'package:app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Semantic colours (design-system/okaerisplit/MASTER.md)
const _colorIOwe = Color(0xFFF87171);   // 我欠別人
const _colorOwedMe = Color(0xFF34D399); // 別人欠我

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(crossGroupDebtsProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待辦'),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(crossGroupDebtsProvider);
              },
              child: debtsAsync.when(
                loading: () => const _PendingTodoSkeleton(),
                error: (error, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppErrorWidget(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(crossGroupDebtsProvider),
                      ),
                    ),
                  ],
                ),
                data: (debts) {
                  final groups = groupsAsync.valueOrNull ?? [];
                  final hasActiveGroups =
                      groups.any((g) => g.status == 'active');

                  if (!hasActiveGroups) {
                    return const _NoGroupsEmptyState();
                  }

                  final iOweItems = debts.where((d) => d.iOwe).toList();
                  final owedItems = debts.where((d) => !d.iOwe).toList();

                  if (iOweItems.isEmpty && owedItems.isEmpty) {
                    return const _AllClearEmptyState();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (iOweItems.isNotEmpty)
                        _DebtSection(
                          title: '你需要付款',
                          items: iOweItems,
                          accentColor: _colorIOwe,
                        ),
                      if (owedItems.isNotEmpty)
                        _DebtSection(
                          title: '別人欠你',
                          items: owedItems,
                          accentColor: _colorOwedMe,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section
// ─────────────────────────────────────────────

class _DebtSection extends StatelessWidget {
  const _DebtSection({
    required this.title,
    required this.items,
    required this.accentColor,
  });

  final String title;
  final List<CrossGroupDebtItem> items;
  final Color accentColor;

  String _subtotal() {
    final currencies = items.map((i) => i.currency).toSet();
    if (currencies.length == 1) {
      final total = items.fold(0.0, (sum, i) => sum + i.amount);
      return '共 ${currencies.first} ${total.toStringAsFixed(0)}';
    }
    return '共 ${items.length} 筆';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _subtotal(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accentColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Items
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: items.asMap().entries.map((e) {
                return _PendingDebtItem(
                  item: e.value,
                  isLast: e.key == items.length - 1,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Debt item
// ─────────────────────────────────────────────

class _PendingDebtItem extends ConsumerWidget {
  const _PendingDebtItem({
    required this.item,
    this.isLast = false,
  });

  final CrossGroupDebtItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final amountPrefix = item.iOwe ? '-' : '+';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () async {
            await context.push('/groups/${item.groupId}');
            if (context.mounted) ref.invalidate(crossGroupDebtsProvider);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                UserAvatar(
                  name: item.counterpartDisplayName,
                  avatarUrl: item.counterpartAvatarUrl,
                  radius: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.counterpartDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$amountPrefix${item.currency} ${item.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────

class _NoGroupsEmptyState extends StatelessWidget {
  const _NoGroupsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_add_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '還沒有群組',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '加入或建立一個群組，開始記帳吧',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => context.go('/groups'),
                child: const Text('前往群組'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllClearEmptyState extends StatelessWidget {
  const _AllClearEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: _colorOwedMe.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                '帳款都清楚了',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '目前所有群組的帳款都已結清',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────

class _PendingTodoSkeleton extends StatelessWidget {
  const _PendingTodoSkeleton();

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.4);
    final dividerColor = Theme.of(context)
        .colorScheme
        .outlineVariant
        .withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionSkeleton(
            surfaceColor: surfaceColor,
            dividerColor: dividerColor,
            rowCount: 2,
          ),
          const SizedBox(height: 20),
          _SectionSkeleton(
            surfaceColor: surfaceColor,
            dividerColor: dividerColor,
            rowCount: 1,
          ),
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({
    required this.surfaceColor,
    required this.dividerColor,
    required this.rowCount,
  });

  final Color surfaceColor;
  final Color dividerColor;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            SkeletonBox(width: 3, height: 16, borderRadius: 2),
            const SizedBox(width: 8),
            SkeletonBox(width: 80, height: 13, borderRadius: 4),
            const Spacer(),
            SkeletonBox(width: 64, height: 11, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 10),
        // Items card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: surfaceColor,
          ),
          child: Column(
            children: List.generate(rowCount, (i) {
              final isLast = i == rowCount - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        SkeletonBox(width: 40, height: 40, borderRadius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(
                                  width: 100, height: 13, borderRadius: 4),
                              const SizedBox(height: 5),
                              SkeletonBox(
                                  width: 64, height: 10, borderRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SkeletonBox(
                                width: 28, height: 10, borderRadius: 4),
                            const SizedBox(height: 3),
                            SkeletonBox(
                                width: 56, height: 16, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 68, color: dividerColor),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
