import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedCurrency = AppConstants.defaultCurrency;
  bool _isLoading = false;
  String? _errorMessage;

  static const _currencies = ['TWD', 'USD', 'JPY', 'EUR', 'KRW'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final createGroup = ref.read(createGroupUseCaseProvider);
    final result = await createGroup(
      name: _nameController.text.trim(),
      type: GroupType.other.name,
      currency: _selectedCurrency,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (groupId) {
        ref.invalidate(groupsProvider);
        context.pop();
        context.push('/groups/$groupId');
      },
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '選擇幣別',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ..._currencies.map((c) => ListTile(
                  title: Text(c),
                  trailing: _selectedCurrency == c
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedCurrency = c);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立群組')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 群組名稱
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '群組名稱',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入群組名稱';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 幣別
                    InkWell(
                      onTap: _showCurrencyPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '幣別',
                          prefixIcon: Icon(Icons.attach_money),
                          suffixIcon: Icon(Icons.chevron_right),
                        ),
                        child: Text(_selectedCurrency),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 固定底部提交按鈕
          _buildSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            FilledButton(
              onPressed: _isLoading ? null : _handleCreate,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('建立群組'),
            ),
          ],
        ),
      ),
    );
  }
}
