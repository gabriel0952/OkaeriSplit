import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:app/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditPaymentInfoSheet extends ConsumerStatefulWidget {
  const EditPaymentInfoSheet({super.key, this.initial});

  final PaymentInfoEntity? initial;

  @override
  ConsumerState<EditPaymentInfoSheet> createState() =>
      _EditPaymentInfoSheetState();
}

class _EditPaymentInfoSheetState extends ConsumerState<EditPaymentInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankCodeController;
  late final TextEditingController _accountNumberController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bankNameController =
        TextEditingController(text: widget.initial?.bankName ?? '');
    _bankCodeController =
        TextEditingController(text: widget.initial?.bankCode ?? '');
    _accountNumberController =
        TextEditingController(text: widget.initial?.accountNumber ?? '');
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final info = PaymentInfoEntity(
      bankName: _bankNameController.text.trim(),
      bankCode: _bankCodeController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
    );

    final updatePaymentInfo = ref.read(updatePaymentInfoUseCaseProvider);
    final result = await updatePaymentInfo(currentUser.id, info);

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(profileProvider);
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
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
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 20),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined),
                  const SizedBox(width: 12),
                  Text(
                    '匯款資訊',
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
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(labelText: '銀行名稱 *'),
              maxLength: 50,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入銀行名稱' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankCodeController,
              decoration: const InputDecoration(
                labelText: '銀行代碼 *',
                hintText: '例：004',
              ),
              keyboardType: TextInputType.number,
              maxLength: 7,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入銀行代碼' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(labelText: '帳號 *'),
              keyboardType: TextInputType.number,
              maxLength: 20,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入帳號' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text(
              '此資訊將對同群組成員可見',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }
}
