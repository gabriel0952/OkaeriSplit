import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:app/features/settlements/presentation/widgets/settlement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(settlementsProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('結算歷史')),
      body: settlementsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(settlementsProvider(groupId)),
        ),
        data: (settlements) {
          if (settlements.isEmpty) {
            return const Center(
              child: Text('目前沒有結算紀錄'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(settlementsProvider(groupId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: settlements.length,
              itemBuilder: (context, index) {
                return SettlementCard(settlement: settlements[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
