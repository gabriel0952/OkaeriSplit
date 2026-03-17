import 'dart:async';

import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // true once the recovery session is confirmed ready
  bool _sessionReady = false;
  bool _linkExpired = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() {
    // Session may already be set if supabase_flutter finished processing
    // the deep link before the screen was built.
    if (Supabase.instance.client.auth.currentSession != null) {
      _sessionReady = true;
      return;
    }

    // Subscribe to catch the event if it fires after we're built.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery ||
          data.event == AuthChangeEvent.signedIn) {
        setState(() => _sessionReady = true);
        _authSub?.cancel();
      }
    });

    // Fallback poll: event may have fired between the null-check and subscribe.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _sessionReady) return;
      if (Supabase.instance.client.auth.currentSession != null) {
        setState(() => _sessionReady = true);
      }
    });

    // Timeout: if session never arrives, the link is expired/invalid.
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted || _sessionReady) return;
      _authSub?.cancel();
      setState(() => _linkExpired = true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final useCase = ref.read(updatePasswordUseCaseProvider);
    final result = await useCase(_passwordController.text);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) => context.go('/dashboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定新密碼')),
      body: SafeArea(
        child: Center(
          child: _linkExpired
              ? _buildExpired()
              : _sessionReady
                  ? _buildForm()
                  : _buildWaiting(),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在驗證連結…'),
      ],
    );
  }

  Widget _buildExpired() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            '連結已失效',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '重設密碼連結已過期或已使用，請重新申請。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => context.go('/forgot-password'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('重新申請重設密碼'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '設定新密碼',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '請輸入您的新密碼。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '新密碼',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) return '請輸入新密碼';
                if (value.length < 8) return '密碼至少需要 8 個字元';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              decoration: InputDecoration(
                labelText: '確認新密碼',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              validator: (value) {
                if (value == null || value.isEmpty) return '請確認新密碼';
                if (value != _passwordController.text) return '兩次密碼輸入不一致';
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('確認更新密碼'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
