import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestLoginScreen extends ConsumerStatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  ConsumerState<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends ConsumerState<GuestLoginScreen> {
  final _groupCodeController = TextEditingController();
  final _claimCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _groupCodeController.dispose();
    _claimCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    final groupCode = _groupCodeController.text.trim().toUpperCase();
    final claimCode = _claimCodeController.text.trim().toUpperCase();

    if (groupCode.length != 6 || claimCode.length != 6) {
      setState(() => _errorMessage = '群組代碼與訪客代碼均須為 6 位');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Call Edge Function
      final response = await supabase.functions.invoke(
        'claim_guest_member',
        body: {
          'group_invite_code': groupCode,
          'claim_code': claimCode,
        },
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['hashed_token'] == null) {
        final error = data?['error'] as String? ?? '認領失敗，請確認代碼是否正確';
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
        return;
      }

      final hashedToken = data['hashed_token'] as String;
      final groupId = data['group_id'] as String;

      // Verify the magic link token hash to establish a session
      await supabase.auth.verifyOTP(
        tokenHash: hashedToken,
        type: OtpType.magiclink,
      );

      if (!mounted) return;

      // Persist groupId so the router can redirect on cold start
      await Hive.box('groups_cache').put('guest_group_id', groupId);

      if (!mounted) return;

      // Route directly to the group
      context.go('/groups/$groupId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('訪客登入')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '以訪客身份瀏覽群組',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '輸入群組邀請碼與訪客代碼\n即可唯讀瀏覽群組帳務',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _groupCodeController,
                decoration: const InputDecoration(
                  labelText: '群組邀請碼（6 位）',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _claimCodeController,
                decoration: const InputDecoration(
                  labelText: '訪客代碼（6 位）',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleClaim,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('進入群組'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
