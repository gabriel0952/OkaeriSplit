import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GuestUpgradeScreen extends ConsumerStatefulWidget {
  const GuestUpgradeScreen({super.key});

  @override
  ConsumerState<GuestUpgradeScreen> createState() => _GuestUpgradeScreenState();
}

class _GuestUpgradeScreenState extends ConsumerState<GuestUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleUpgrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final upgrade = ref.read(upgradeGuestAccountUseCaseProvider);
    final result = await upgrade(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (_) {
        context.go('/dashboard');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立正式帳號')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '升級為正式帳號',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '設定 email 與密碼，保留所有帳務紀錄\n並解鎖完整 app 功能',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: '顯示名稱',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '請輸入顯示名稱';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '請輸入 Email';
                    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                    if (!emailRegex.hasMatch(v.trim())) return '請輸入有效的 Email 格式';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleUpgrade(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '請輸入密碼';
                    if (v.length < 8) return '密碼至少需要 8 個字元';
                    return null;
                  },
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpgrade,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('建立帳號'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
