abstract final class AppConstants {
  // Supabase — replace with real values before deployment
  static const String supabaseUrl = 'https://wwkkdbirxaxtdffnfqrf.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3a2tkYmlyeGF4dGRmZm5mcXJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5NTg2MDAsImV4cCI6MjA4NjUzNDYwMH0.d91jgkYO0D_4nMww2RmR0sRxV4xXFI5vyewocEWImfg';

  static const String appName = 'OkaeriSplit';
  static const String defaultCurrency = 'TWD';
}

enum ExpenseCategory {
  food('餐飲'),
  transport('交通'),
  accommodation('住宿'),
  entertainment('娛樂'),
  dailyNecessities('日用品'),
  other('其他');

  const ExpenseCategory(this.label);
  final String label;
}

enum GroupType {
  roommate('合租'),
  travel('旅行'),
  event('活動'),
  other('其他');

  const GroupType(this.label);
  final String label;
}

enum SplitType {
  equal('均分'),
  customRatio('自訂比例'),
  fixedAmount('指定金額');

  const SplitType(this.label);
  final String label;
}
