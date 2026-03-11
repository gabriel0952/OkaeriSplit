abstract final class AppConstants {
  // Supabase — injected via --dart-define-from-file=dart_defines.json at build time
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String redirectUrl = 'com.raycat.okaerisplit://login-callback';
  static const String appName = 'OkaeriSplit';
  static const String defaultCurrency = 'TWD';
}

enum ExpenseCategory {
  food('餐飲'),
  transport('交通'),
  accommodation('住宿'),
  entertainment('娛樂'),
  dailyNecessities('日用品');

  const ExpenseCategory(this.label);
  final String label;
}

/// Maps built-in category keys to their display labels.
const builtInCategoryLabels = <String, String>{
  'food': '餐飲',
  'transport': '交通',
  'accommodation': '住宿',
  'entertainment': '娛樂',
  'daily_necessities': '日用品',
};

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
  fixedAmount('指定金額'),
  itemized('項目拆分');

  const SplitType(this.label);
  final String label;
}
