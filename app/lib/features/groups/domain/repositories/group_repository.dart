import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/entities/group_exchange_rate_entity.dart';

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

  Future<AppResult<void>> removeMember({
    required String groupId,
    required String userId,
  });

  Future<AppResult<List<GroupMemberEntity>>> getGroupMembers(String groupId);

  Future<AppResult<List<Map<String, dynamic>>>> searchUsers(String query);

  Future<AppResult<void>> inviteUserToGroup({
    required String groupId,
    required String userId,
  });

  Future<AppResult<void>> deleteGroup(String groupId);

  Future<AppResult<String>> createShareLink(String groupId);

  Future<AppResult<void>> updateGroupName(String groupId, String name);

  Future<AppResult<List<GroupExchangeRateEntity>>> getExchangeRates(String groupId);

  Future<AppResult<void>> setExchangeRate(
    String groupId,
    String currency,
    double rate,
  );

  Future<AppResult<void>> deleteExchangeRate(String groupId, String currency);
}
