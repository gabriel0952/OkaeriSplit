class UserEntity {
  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.defaultCurrency = 'TWD',
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String defaultCurrency;
}
