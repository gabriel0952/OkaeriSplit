import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/data/datasources/supabase_group_datasource.dart';
import 'package:app/features/groups/data/repositories/group_repository_impl.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';
import 'package:app/features/groups/domain/usecases/create_group.dart';
import 'package:app/features/groups/domain/usecases/get_group_detail.dart';
import 'package:app/features/groups/domain/usecases/get_group_members.dart';
import 'package:app/features/groups/domain/usecases/get_groups.dart';
import 'package:app/features/groups/domain/usecases/join_group_by_code.dart';
import 'package:app/features/groups/domain/usecases/delete_group.dart';
import 'package:app/features/groups/domain/usecases/invite_user.dart';
import 'package:app/features/groups/domain/usecases/leave_group.dart';
import 'package:app/features/groups/domain/usecases/search_users.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final supabaseGroupDataSourceProvider = Provider<SupabaseGroupDataSource>((
  ref,
) {
  return SupabaseGroupDataSource(ref.watch(supabaseClientProvider));
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(ref.watch(supabaseGroupDataSourceProvider));
});

// Use cases
final createGroupUseCaseProvider = Provider<CreateGroup>((ref) {
  return CreateGroup(ref.watch(groupRepositoryProvider));
});

final getGroupsUseCaseProvider = Provider<GetGroups>((ref) {
  return GetGroups(ref.watch(groupRepositoryProvider));
});

final getGroupDetailUseCaseProvider = Provider<GetGroupDetail>((ref) {
  return GetGroupDetail(ref.watch(groupRepositoryProvider));
});

final getGroupMembersUseCaseProvider = Provider<GetGroupMembers>((ref) {
  return GetGroupMembers(ref.watch(groupRepositoryProvider));
});

final joinGroupByCodeUseCaseProvider = Provider<JoinGroupByCode>((ref) {
  return JoinGroupByCode(ref.watch(groupRepositoryProvider));
});

final leaveGroupUseCaseProvider = Provider<LeaveGroup>((ref) {
  return LeaveGroup(ref.watch(groupRepositoryProvider));
});

final deleteGroupUseCaseProvider = Provider<DeleteGroup>((ref) {
  return DeleteGroup(ref.watch(groupRepositoryProvider));
});

final searchUsersUseCaseProvider = Provider<SearchUsers>((ref) {
  return SearchUsers(ref.watch(groupRepositoryProvider));
});

final inviteUserUseCaseProvider = Provider<InviteUser>((ref) {
  return InviteUser(ref.watch(groupRepositoryProvider));
});

// Presentation providers
final groupsProvider = FutureProvider<List<GroupEntity>>((ref) async {
  final getGroups = ref.watch(getGroupsUseCaseProvider);
  final result = await getGroups();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (groups) => groups,
  );
});

final groupDetailProvider = FutureProvider.family<GroupEntity, String>((
  ref,
  groupId,
) async {
  final getGroupDetail = ref.watch(getGroupDetailUseCaseProvider);
  final result = await getGroupDetail(groupId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (group) => group,
  );
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMemberEntity>, String>((
      ref,
      groupId,
    ) async {
      final getGroupMembers = ref.watch(getGroupMembersUseCaseProvider);
      final result = await getGroupMembers(groupId);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (members) => members,
      );
    });
