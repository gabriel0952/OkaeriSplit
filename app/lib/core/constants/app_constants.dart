abstract final class AppConstants {
  // Supabase — replace with real values before deployment
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';

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
  event('活動');

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
