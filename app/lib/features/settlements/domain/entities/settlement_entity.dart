class BalanceEntity {
  const BalanceEntity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.totalPaid,
    required this.totalOwed,
    required this.netBalance,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;
}

class OverallBalanceEntity {
  const OverallBalanceEntity({
    required this.groupId,
    required this.groupName,
    required this.netBalance,
  });

  final String groupId;
  final String groupName;
  final double netBalance;
}

class SettlementEntity {
  const SettlementEntity({
    required this.id,
    required this.groupId,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.currency,
    required this.settledAt,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String fromUser;
  final String toUser;
  final double amount;
  final String currency;
  final DateTime settledAt;
  final DateTime createdAt;
}

class SimplifiedDebtEntity {
  const SimplifiedDebtEntity({
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.toDisplayName,
    this.fromAvatarUrl,
    this.toAvatarUrl,
    required this.amount,
  });

  final String fromUserId;
  final String fromDisplayName;
  final String toUserId;
  final String toDisplayName;
  final String? fromAvatarUrl;
  final String? toAvatarUrl;
  final double amount;
}
