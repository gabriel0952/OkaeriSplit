import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    super.key,
    required this.groupId,
    required this.existingMemberIds,
  });

  final String groupId;
  final Set<String> existingMemberIds;

  @override
  ConsumerState<InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _isInviting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final searchUsers = ref.read(searchUsersUseCaseProvider);
    final result = await searchUsers(query.trim());

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        setState(() => _isSearching = false);
      },
      (users) {
        setState(() {
          _results = users
              .where((u) => !widget.existingMemberIds.contains(u['id']))
              .toList();
          _isSearching = false;
        });
      },
    );
  }

  Future<void> _invite(Map<String, dynamic> user) async {
    setState(() => _isInviting = true);

    final inviteUser = ref.read(inviteUserUseCaseProvider);
    final result = await inviteUser(
      groupId: widget.groupId,
      userId: user['id'] as String,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        setState(() => _isInviting = false);
      },
      (_) {
        ref.invalidate(groupMembersProvider(widget.groupId));
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已邀請 ${user['display_name'] ?? user['email']}',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邀請成員'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜尋 Email 或暱稱',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_results.isEmpty &&
                _searchController.text.trim().length >= 2)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('找不到符合的用戶'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    final name =
                        user['display_name'] as String? ?? '';
                    final email = user['email'] as String? ?? '';
                    final avatarUrl = user['avatar_url'] as String?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child:
                            avatarUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name.isNotEmpty ? name : email),
                      subtitle: name.isNotEmpty ? Text(email) : null,
                      trailing: _isInviting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      onTap: _isInviting ? null : () => _invite(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
