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
  GroupType _selectedType = GroupType.roommate;
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
      type: _selectedType.name,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立群組')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 24),
              Text('群組類型', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<GroupType>(
                segments: GroupType.values
                    .where((t) => t != GroupType.other)
                    .map(
                      (type) =>
                          ButtonSegment(value: type, label: Text(type.label)),
                    )
                    .toList(),
                selected: {_selectedType},
                onSelectionChanged: (selected) {
                  setState(() => _selectedType = selected.first);
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: '幣別',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('建立'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
