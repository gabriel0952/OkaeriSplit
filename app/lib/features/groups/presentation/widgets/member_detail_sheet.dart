import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:app/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberDetailSheet extends ConsumerStatefulWidget {
  const MemberDetailSheet({
    super.key,
    required this.member,
    required this.resolvedName,
    required this.canRemove,
    required this.onRemove,
  });

  final GroupMemberEntity member;
  final String resolvedName;
  final bool canRemove;
  final Future<void> Function() onRemove;

  @override
  ConsumerState<MemberDetailSheet> createState() => _MemberDetailSheetState();
}

class _MemberDetailSheetState extends ConsumerState<MemberDetailSheet> {
  PaymentInfoEntity? _paymentInfo;
  bool _loadingPaymentInfo = true;
  bool _paymentInfoError = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    final getPaymentInfo = ref.read(getPaymentInfoUseCaseProvider);
    final result = await getPaymentInfo(widget.member.userId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _loadingPaymentInfo = false;
        _paymentInfoError = true;
      }),
      (info) => setState(() {
        _loadingPaymentInfo = false;
        _paymentInfo = info;
      }),
    );
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label已複製')));
  }

  Future<void> _handleRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成員'),
        content: Text('確定要將「${widget.resolvedName}」從群組中移除嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onRemove();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final member = widget.member;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: avatar + name + close
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.resolvedName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (member.isGuest)
                      Text(
                        '訪客',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      )
                    else if (member.role == 'owner')
                      Text(
                        '管理員',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Email（訪客不顯示）
          if (!member.isGuest &&
              member.email != null &&
              member.email!.isNotEmpty)
            _InfoRow(
              icon: Icons.email_outlined,
              label: '信箱',
              value: member.email!,
              onCopy: () => _copyText(member.email!, '信箱'),
            ),

          // 訪客邀請碼（僅 owner 可見且尚未被認領）
          if (member.isGuest &&
              widget.canRemove &&
              member.claimCode != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.vpn_key_outlined,
              label: '訪客代碼',
              value: member.claimCode!,
              onCopy: () => _copyText(member.claimCode!, '訪客代碼'),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4),
              child: Text(
                '分享此代碼讓訪客認領帳號',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],

          // Payment info
          if (_loadingPaymentInfo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_paymentInfoError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '無法載入匯款資訊',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else if (_paymentInfo != null) ...[
            const Divider(height: 28),
            Text(
              '匯款資訊',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.account_balance_outlined,
              label: '銀行',
              value: '${_paymentInfo!.bankName}（${_paymentInfo!.bankCode}）',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.numbers_outlined,
              label: '帳號',
              value: _paymentInfo!.accountNumber,
              onCopy: () => _copyText(_paymentInfo!.accountNumber, '帳號'),
            ),
          ] else ...[
            const Divider(height: 28),
            Text(
              '對方尚未設定匯款資訊',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],

          // Remove member button
          if (widget.canRemove) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _handleRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('移除成員'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
