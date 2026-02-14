import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class SearchUsers {
  const SearchUsers(this._repository);
  final GroupRepository _repository;

  Future<AppResult<List<Map<String, dynamic>>>> call(String query) {
    return _repository.searchUsers(query);
  }
}
