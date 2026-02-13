import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class GetGroups {
  const GetGroups(this._repository);
  final GroupRepository _repository;

  Future<AppResult<List<GroupEntity>>> call() {
    return _repository.getGroups();
  }
}
