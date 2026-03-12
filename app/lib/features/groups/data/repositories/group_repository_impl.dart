import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/data/datasources/hive_group_datasource.dart';
import 'package:app/features/groups/data/datasources/supabase_group_datasource.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';
import 'package:fpdart/fpdart.dart';

class GroupRepositoryImpl implements GroupRepository {
  const GroupRepositoryImpl(this._remote, this._local, this._isOnline);
  final SupabaseGroupDataSource _remote;
  final HiveGroupDataSource _local;
  final bool _isOnline;

  @override
  Future<AppResult<List<GroupEntity>>> getGroups() async {
    if (!_isOnline) {
      return Right(_local.getGroups());
    }
    try {
      final groups = await _remote.getGroups();
      await _local.saveGroups(groups);
      return Right(groups);
    } catch (e) {
      // Network failed — fall back to Hive cache so app doesn't crash offline.
      final cached = _local.getGroups();
      if (cached.isNotEmpty) return Right(cached);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<GroupEntity>> getGroupDetail(String groupId) async {
    if (!_isOnline) {
      // Try to find the group in the cached list.
      final cached = _local.getGroups();
      final match = cached.where((g) => g.id == groupId);
      if (match.isNotEmpty) return Right(match.first);
      return Left(const ServerFailure('離線中，無法取得群組詳情'));
    }
    try {
      final group = await _remote.getGroupDetail(groupId);
      return Right(group);
    } catch (e) {
      final cached = _local.getGroups();
      final match = cached.where((g) => g.id == groupId);
      if (match.isNotEmpty) return Right(match.first);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<String>> createGroup({
    required String name,
    required String type,
    required String currency,
  }) async {
    try {
      final groupId = await _remote.createGroup(
        name: name,
        type: type,
        currency: currency,
      );
      return Right(groupId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<String>> joinGroupByCode(String inviteCode) async {
    try {
      final groupId = await _remote.joinGroupByCode(inviteCode);
      return Right(groupId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> leaveGroup(String groupId) async {
    try {
      await _remote.leaveGroup(groupId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<GroupMemberEntity>>> getGroupMembers(
    String groupId,
  ) async {
    if (!_isOnline) {
      return Right(_local.getMembers(groupId));
    }
    try {
      final members = await _remote.getGroupMembers(groupId);
      await _local.saveMembers(groupId, members);
      return Right(members);
    } catch (e) {
      // Fall back to cache on network error.
      return Right(_local.getMembers(groupId));
    }
  }

  @override
  Future<AppResult<List<Map<String, dynamic>>>> searchUsers(
    String query,
  ) async {
    try {
      final users = await _remote.searchUsers(query);
      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> inviteUserToGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _remote.inviteUserToGroup(groupId: groupId, userId: userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> deleteGroup(String groupId) async {
    try {
      await _remote.deleteGroup(groupId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
