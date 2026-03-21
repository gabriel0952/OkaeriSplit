import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class UpdateGroupName {
  const UpdateGroupName(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call(String groupId, String name) {
    return _repository.updateGroupName(groupId, name);
  }
}
