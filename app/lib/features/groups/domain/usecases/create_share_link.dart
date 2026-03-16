import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class CreateShareLink {
  const CreateShareLink(this._repository);
  final GroupRepository _repository;

  Future<AppResult<String>> call(String groupId) {
    return _repository.createShareLink(groupId);
  }
}
