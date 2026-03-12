import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/expandable_fab.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/groups/presentation/widgets/group_card.dart';
import 'package:app/features/groups/presentation/widgets/join_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                if (groups.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.group_outlined,
                    title: '還沒有群組',
                    subtitle: '建立或加入一個群組開始分帳吧',
                    action: FilledButton.tonal(
                      onPressed: () => context.push('/groups/create'),
                      child: const Text('建立群組'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(groupsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return GroupCard(
                        group: group,
                        onTap: () => context.push('/groups/${group.id}'),
                      );
                    },
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
            onPressed: () => context.push('/groups/create'),
          ),
        ],
      ),
    );
  }
}
