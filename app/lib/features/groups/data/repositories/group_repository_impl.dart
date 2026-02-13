import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/data/datasources/supabase_group_datasource.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';
import 'package:fpdart/fpdart.dart';

class GroupRepositoryImpl implements GroupRepository {
  const GroupRepositoryImpl(this._dataSource);
  final SupabaseGroupDataSource _dataSource;

  @override
  Future<AppResult<List<GroupEntity>>> getGroups() async {
    try {
      final groups = await _dataSource.getGroups();
      return Right(groups);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<GroupEntity>> getGroupDetail(String groupId) async {
    try {
      final group = await _dataSource.getGroupDetail(groupId);
      return Right(group);
    } catch (e) {
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
      final groupId = await _dataSource.createGroup(
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
      final groupId = await _dataSource.joinGroupByCode(inviteCode);
      return Right(groupId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> leaveGroup(String groupId) async {
    try {
      await _dataSource.leaveGroup(groupId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<GroupMemberEntity>>> getGroupMembers(
    String groupId,
  ) async {
    try {
      final members = await _dataSource.getGroupMembers(groupId);
      return Right(members);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
