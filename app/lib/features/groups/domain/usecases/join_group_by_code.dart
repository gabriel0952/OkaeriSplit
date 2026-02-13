import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class JoinGroupByCode {
  const JoinGroupByCode(this._repository);
  final GroupRepository _repository;

  Future<AppResult<String>> call(String inviteCode) {
    return _repository.joinGroupByCode(inviteCode);
  }
}
