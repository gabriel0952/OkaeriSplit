import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class GetGroupDetail {
  const GetGroupDetail(this._repository);
  final GroupRepository _repository;

  Future<AppResult<GroupEntity>> call(String groupId) {
    return _repository.getGroupDetail(groupId);
  }
}
