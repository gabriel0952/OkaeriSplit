import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class InviteUser {
  const InviteUser(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call({
    required String groupId,
    required String userId,
  }) {
    return _repository.inviteUserToGroup(groupId: groupId, userId: userId);
  }
}
