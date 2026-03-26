import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/expandable_fab.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/groups/presentation/widgets/group_card.dart';
import 'package:app/features/groups/presentation/widgets/create_group_sheet.dart';
import 'package:app/features/groups/presentation/widgets/join_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  bool _archivedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('群組')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: groupsAsync.when(
              loading: () => const GroupListSkeleton(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(groupsProvider),
              ),
              data: (groups) {
                final active = groups.where((g) => !g.isArchived).toList();
                final archived = groups.where((g) => g.isArchived).toList();

                if (active.isEmpty && archived.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.group_outlined,
                    title: '還沒有群組',
                    subtitle: '建立或加入一個群組開始分帳吧',
                    action: FilledButton.tonal(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => const CreateGroupSheet(),
                      ),
                      child: const Text('建立群組'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(groupsProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Active groups
                      if (active.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '沒有進行中的群組',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ...active.map((group) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GroupCard(
                            group: group,
                            onTap: () => context.push('/groups/${group.id}'),
                          ),
                        )),

                      // Archived section
                      if (archived.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => setState(() => _archivedExpanded = !_archivedExpanded),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.archive_outlined,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '已結束（${archived.length}）',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _archivedExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_archivedExpanded)
                          ...archived.map((group) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Opacity(
                              opacity: 0.6,
                              child: GroupCard(
                                group: group,
                                onTap: () => context.push('/groups/${group.id}'),
                              ),
                            ),
                          )),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ExpandableFab(
        children: [
          ExpandableFabChild(
            icon: Icons.group_add_outlined,
            label: '加入群組',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const JoinGroupDialog(),
            ),
          ),
          ExpandableFabChild(
            icon: Icons.add,
            label: '建立群組',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const CreateGroupSheet(),
            ),
          ),
        ],
      ),
    );
  }
}
