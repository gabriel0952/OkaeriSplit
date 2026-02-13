import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class CreateGroup {
  const CreateGroup(this._repository);
  final GroupRepository _repository;

  Future<AppResult<String>> call({
    required String name,
    required String type,
    required String currency,
  }) {
    return _repository.createGroup(name: name, type: type, currency: currency);
  }
}
