import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class DeleteGroup {
  const DeleteGroup(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call(String groupId) {
    return _repository.deleteGroup(groupId);
  }
}
