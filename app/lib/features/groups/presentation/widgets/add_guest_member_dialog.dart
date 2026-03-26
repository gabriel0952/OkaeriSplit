import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;

class AddGuestMemberDialog extends ConsumerStatefulWidget {
  const AddGuestMemberDialog({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddGuestMemberDialog> createState() =>
      _AddGuestMemberDialogState();
}

class _AddGuestMemberDialogState extends ConsumerState<AddGuestMemberDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _claimCode;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGuest() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = '請輸入顯示名稱');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'create_guest_member',
        body: {
          'group_id': widget.groupId,
          'display_name': name,
        },
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['claim_code'] == null) {
        final error = data?['error'] as String? ?? '建立失敗，請稍後再試';
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
        return;
      }

      ref.invalidate(groupMembersProvider(widget.groupId));
      setState(() {
        _isLoading = false;
        _claimCode = data['claim_code'] as String;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _copyCode() {
    if (_claimCode == null) return;
    Clipboard.setData(ClipboardData(text: _claimCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('訪客代碼已複製')),
    );
  }

  Future<void> _shareCode(String groupInviteCode) async {
    if (_claimCode == null) return;
    await Share.share(
      '請開啟 OkaeriSplit APP，輸入以下代碼即可以訪客身份瀏覽帳務：\n'
      '群組代碼：$groupInviteCode\n'
      '訪客代碼：$_claimCode',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.person_add_outlined),
                const SizedBox(width: 12),
                Text(
                  '新增訪客成員',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          if (_claimCode == null) ...[
            // Name input form
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: '顯示名稱（如：小明）',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _createGuest(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _createGuest,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('建立訪客'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Success — show claim code
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '已新增訪客成員：${_nameController.text.trim()}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '訪客代碼',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _claimCode!,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '請對方開啟 APP 並依序輸入\n群組邀請碼與此訪客代碼',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Get invite code for sharing
                  Consumer(
                    builder: (context, ref, _) {
                      final groupAsync = ref.watch(
                        groupDetailProvider(widget.groupId),
                      );
                      final inviteCode =
                          groupAsync.valueOrNull?.inviteCode ?? '';
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyCode,
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('複製代碼'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: inviteCode.isNotEmpty
                                  ? () => _shareCode(inviteCode)
                                  : null,
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('分享'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
