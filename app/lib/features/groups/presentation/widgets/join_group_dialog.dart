import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinGroupDialog extends ConsumerStatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  ConsumerState<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<JoinGroupDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = '請輸入邀請碼');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final joinGroup = ref.read(joinGroupByCodeUseCaseProvider);
    final result = await joinGroup(code);

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
    return AlertDialog(
      title: const Text('加入群組'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '邀請碼',
              hintText: '輸入 6 碼邀請碼',
              errorText: _errorMessage,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        FilledButton.tonal(
          onPressed: _isLoading ? null : () => context.pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleJoin,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('加入'),
        ),
      ],
    );
  }
}
