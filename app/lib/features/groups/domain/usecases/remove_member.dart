import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class RemoveMember {
  const RemoveMember(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call({
    required String groupId,
    required String userId,
  }) {
    return _repository.removeMember(groupId: groupId, userId: userId);
  }
}
