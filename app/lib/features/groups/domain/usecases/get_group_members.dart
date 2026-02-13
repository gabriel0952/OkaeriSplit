import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class GetGroupMembers {
  const GetGroupMembers(this._repository);
  final GroupRepository _repository;

  Future<AppResult<List<GroupMemberEntity>>> call(String groupId) {
    return _repository.getGroupMembers(groupId);
  }
}
