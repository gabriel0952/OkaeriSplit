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
  final _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String? _invitingUserId;

  @override
  void initState() {
    super.initState();
    // Auto-focus search after sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final userId = user['id'] as String;
    setState(() => _invitingUserId = userId);

    final inviteUser = ref.read(inviteUserUseCaseProvider);
    final result = await inviteUser(
      groupId: widget.groupId,
      userId: userId,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        setState(() => _invitingUserId = null);
      },
      (_) {
        ref.invalidate(groupMembersProvider(widget.groupId));
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已邀請 ${user['display_name'] ?? user['email']}'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().length >= 2;

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
                color:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                  '邀請成員',
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

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: '輸入 Email 或暱稱搜尋…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Results area
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            )
          else if (hasQuery && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 40,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '找不到符合的用戶',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          else if (!hasQuery && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '至少輸入 2 個字開始搜尋',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  final name = user['display_name'] as String? ?? '';
                  final email = user['email'] as String? ?? '';
                  final avatarUrl = user['avatar_url'] as String?;
                  final userId = user['id'] as String;
                  final isInviting = _invitingUserId == userId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              (name.isNotEmpty ? name : email)
                                      .isNotEmpty
                                  ? (name.isNotEmpty ? name : email)[0]
                                      .toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    title: Text(
                      name.isNotEmpty ? name : email,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: name.isNotEmpty ? Text(email) : null,
                    trailing: isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : FilledButton(
                            onPressed: _invitingUserId != null
                                ? null
                                : () => _invite(user),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 36),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                            ),
                            child: const Text('邀請'),
                          ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
