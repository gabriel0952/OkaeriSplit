import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';

class MarkSettled {
  const MarkSettled(this._repository);
  final SettlementRepository _repository;

  Future<AppResult<String>> call({
    required String groupId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String currency,
  }) {
    return _repository.markSettled(
      groupId: groupId,
      fromUser: fromUser,
      toUser: toUser,
      amount: amount,
      currency: currency,
    );
  }
}
