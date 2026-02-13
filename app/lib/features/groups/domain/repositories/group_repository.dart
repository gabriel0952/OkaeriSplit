import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';

abstract class GroupRepository {
  Future<AppResult<List<GroupEntity>>> getGroups();

  Future<AppResult<GroupEntity>> getGroupDetail(String groupId);

  Future<AppResult<String>> createGroup({
    required String name,
    required String type,
    required String currency,
  });

  Future<AppResult<String>> joinGroupByCode(String inviteCode);

  Future<AppResult<void>> leaveGroup(String groupId);

  Future<AppResult<List<GroupMemberEntity>>> getGroupMembers(String groupId);
}
