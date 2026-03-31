import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/gemini_scan_settings_provider.dart';
import 'package:app/features/profile/presentation/providers/profile_provider.dart';
import 'package:app/features/profile/presentation/widgets/gemini_scan_settings_sheet.dart';
import 'package:app/features/profile/presentation/widgets/edit_payment_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _currencies = ['TWD', 'USD', 'JPY', 'EUR', 'GBP', 'KRW', 'CNY'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final geminiSettingsAsync = ref.watch(currentGeminiScanSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (profile) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                profile.displayName.isNotEmpty
                                    ? profile.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 36),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('顯示名稱'),
                            subtitle: Text(profile.displayName),
                            trailing: Icon(
                              Icons.edit,
                              color: isOnline
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: isOnline
                                ? () => _editDisplayName(
                                    context,
                                    ref,
                                    profile.displayName,
                                  )
                                : () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('離線時無法編輯個人資料'),
                                        ),
                                      ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('電子郵件'),
                            subtitle: Text(profile.email),
                          ),
                          if (!profile.isGuest) ...[
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('匯款資訊'),
                              subtitle: profile.paymentInfo != null
                                  ? Text(
                                      '${profile.paymentInfo!.bankName} (${profile.paymentInfo!.bankCode})${profile.paymentInfo!.accountNumber}',
                                    )
                                  : const Text('尚未設定'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: isOnline
                                  ? () =>
                                        _editPaymentInfo(context, ref, profile)
                                  : () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text('離線時無法編輯個人資料'),
                                          ),
                                        ),
                            ),
                          ],
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('預設幣別'),
                            subtitle: Text(profile.defaultCurrency),
                            trailing: Icon(
                              Icons.edit,
                              color: isOnline
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: isOnline
                                ? () => _editCurrency(
                                    context,
                                    ref,
                                    profile.defaultCurrency,
                                  )
                                : () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('離線時無法編輯個人資料'),
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.dark_mode_outlined),
                            title: const Text('深色模式'),
                            trailing: DropdownButton<ThemeMode>(
                              value: ref.watch(themeModeProvider),
                              underline: const SizedBox.shrink(),
                              onChanged: (mode) {
                                if (mode != null) {
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .set(mode);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('跟隨系統'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('淺色'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('深色'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: geminiSettingsAsync.when(
                        loading: () => const ListTile(
                          leading: Icon(Icons.cloud_outlined),
                          title: Text('Gemini 掃描'),
                          subtitle: Text('讀取設定中...'),
                        ),
                        error: (_, _) => const ListTile(
                          leading: Icon(Icons.cloud_outlined),
                          title: Text('Gemini 掃描'),
                          subtitle: Text('無法讀取設定'),
                        ),
                        data: (settings) => ListTile(
                          leading: const Icon(Icons.cloud_outlined),
                          title: const Text('Gemini 掃描'),
                          subtitle: Text(
                            settings == null
                                ? '請先登入帳號後再設定'
                                : settings.hasApiKey
                                ? '已設定 ${settings.maskedApiKey ?? ''}'
                                : '尚未設定 API key',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: isOnline
                              ? () => _editGeminiScanSettings(
                                  context,
                                  ref,
                                  settings?.maskedApiKey,
                                )
                              : () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('離線時無法編輯個人資料'),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('確認登出'),
                            content: const Text('確定要登出嗎？'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: const Text('登出'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref.read(signOutUseCaseProvider).call();
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('登出'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _deleteAccount(context, ref),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('刪除帳號'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改顯示名稱'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '輸入新名稱'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !context.mounted) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final updateProfile = ref.read(updateProfileUseCaseProvider);
    final result = await updateProfile(
      userId: currentUser.id,
      displayName: newName,
    );

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(profileProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新顯示名稱')));
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteAccount = ref.read(deleteAccountUseCaseProvider);
    final result = await deleteAccount();

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗：${failure.message}')));
      },
      (_) {
        // Account deleted, auth state change will redirect to login
      },
    );
  }

  Future<void> _editPaymentInfo(
    BuildContext context,
    WidgetRef ref,
    UserEntity profile,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditPaymentInfoSheet(initial: profile.paymentInfo),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(profileProvider);
    }
  }

  Future<void> _editCurrency(
    BuildContext context,
    WidgetRef ref,
    String currentCurrency,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('選擇預設幣別'),
        children: _currencies.map((currency) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(currency),
            child: Text(
              currency,
              style: TextStyle(
                fontWeight: currency == currentCurrency
                    ? FontWeight.bold
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || selected == currentCurrency || !context.mounted) {
      return;
    }

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final updateProfile = ref.read(updateProfileUseCaseProvider);
    final result = await updateProfile(
      userId: currentUser.id,
      defaultCurrency: selected,
    );

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(profileProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已更新預設幣別為 $selected')));
      },
    );
  }

  Future<void> _editGeminiScanSettings(
    BuildContext context,
    WidgetRef ref,
    String? maskedApiKey,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GeminiScanSettingsSheet(maskedApiKey: maskedApiKey),
    );

    if (updated == true && context.mounted) {
      ref.invalidate(currentGeminiScanSettingsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新 Gemini 掃描設定')));
    }
  }
}

// ── 刪除帳號確認 Dialog ────────────────────────────────────────────────────────
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _controller.text.trim() == '刪除';
    return AlertDialog(
      title: const Text('刪除帳號'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '此操作無法復原。您的所有資料將被永久刪除。',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text('請輸入「刪除」以確認：'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '刪除',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('確認刪除'),
        ),
      ],
    );
  }
}
