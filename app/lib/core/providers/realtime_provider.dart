import 'dart:async';

import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Subscribes to realtime changes on the `expenses` table for a given group.
///
/// Emits an incrementing counter on each change so that [ref.listen] in
/// widgets can detect every event (Riverpod skips callbacks when the value
/// is identical, so emitting `void` / `null` would only fire once).
final realtimeExpensesProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var eventCount = 0;
  final channel = client.channel('expenses:$groupId');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (payload) {
          ref.invalidate(expensesProvider(groupId));
          controller.add(++eventCount);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// Subscribes to realtime changes on the `group_members` table for a given group.
final realtimeGroupMembersProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var eventCount = 0;
  final channel = client.channel('group_members:$groupId');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (payload) {
          ref.invalidate(groupMembersProvider(groupId));
          controller.add(++eventCount);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// Subscribes to realtime changes on the `settlements` table for a given group.
final realtimeSettlementsProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var eventCount = 0;
  final channel = client.channel('settlements:$groupId');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settlements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (payload) {
          ref.invalidate(balancesProvider(groupId));
          ref.invalidate(settlementsProvider(groupId));
          controller.add(++eventCount);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
