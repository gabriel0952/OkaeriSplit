import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/expense_card.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/utils/resolve_display_name.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;

class GroupHomeScreen extends ConsumerStatefulWidget {
  const GroupHomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends ConsumerState<GroupHomeScreen> {
  String get groupId => widget.groupId;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showSearch = false;
  bool _headerCollapsed = false;
  bool _debtExpanded = true;
  Set<String> _selectedCategories = {};
  String? _selectedPayer;
  DateTimeRange? _dateRange;
  bool _isSharing = false;

  // 群組名稱高度 (headlineMedium) + top padding，滾超過即顯示 toolbar 標題
  static const _collapsedThreshold = 52.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isOnlineProvider)) {
        ref.read(syncServiceProvider).flush();
      }
      ref.listenManual(isOnlineProvider, (prev, next) {
        if (next == true && prev == false) {
          ref.read(syncServiceProvider).flush();
        }
      });
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final collapsed = _scrollController.offset >= _collapsedThreshold;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        Future.microtask(() => _searchFocusNode.requestFocus());
      } else {
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  List<ExpenseEntity> _applyFilters(List<ExpenseEntity> expenses) {
    var filtered = expenses;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((e) => e.description.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where((e) => _selectedCategories.contains(e.category))
          .toList();
    }

    if (_selectedPayer != null) {
      filtered = filtered.where((e) => e.paidBy == _selectedPayer).toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((e) {
        final date = DateTime(
          e.expenseDate.year,
          e.expenseDate.month,
          e.expenseDate.day,
        );
        return !date.isBefore(_dateRange!.start) &&
            !date.isAfter(_dateRange!.end);
      }).toList();
    }

    return filtered;
  }

  String _categoryLabel(
    String key,
    List<GroupCategoryEntity> customCategories,
  ) {
    if (builtInCategoryLabels.containsKey(key)) {
      return builtInCategoryLabels[key]!;
    }
    final custom = customCategories.where((c) => c.id == key);
    if (custom.isNotEmpty) return custom.first.name;
    return key;
  }

  int get _advancedFilterCount =>
      (_selectedCategories.isNotEmpty ? 1 : 0) +
      (_selectedPayer != null ? 1 : 0) +
      (_dateRange != null ? 1 : 0);

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _advancedFilterCount > 0;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategories = {};
      _selectedPayer = null;
      _dateRange = null;
    });
  }

  void _showExpenseActions(
    BuildContext context,
    ExpenseEntity expense,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('複製此消費'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(
                  '/groups/$groupId/add-expense',
                  extra: expense,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final expenses =
        ref.read(expensesProvider(groupId)).valueOrNull ?? [];
    final members =
        ref.read(groupMembersProvider(groupId)).valueOrNull ?? [];
    final customCategories =
        ref.read(groupCategoriesProvider(groupId)).valueOrNull ?? [];
    final allCategories = expenses.map((e) => e.category).toSet();
    final memberMap = {for (final m in members) m.userId: m.displayName};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var localCategories = Set<String>.from(_selectedCategories);
        var localPayer = _selectedPayer;
        var localDateRange = _dateRange;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void applyAndClose() {
              setState(() {
                _selectedCategories = localCategories;
                _selectedPayer = localPayer;
                _dateRange = localDateRange;
              });
              Navigator.of(sheetCtx).pop();
            }

            final hasLocalFilters = localCategories.isNotEmpty ||
                localPayer != null ||
                localDateRange != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          '篩選條件',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (hasLocalFilters)
                          TextButton(
                            onPressed: () => setSheetState(() {
                              localCategories = {};
                              localPayer = null;
                              localDateRange = null;
                            }),
                            child: const Text('全部清除'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (allCategories.isNotEmpty) ...[
                            Text(
                              '分類',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allCategories.map((cat) {
                                final selected =
                                    localCategories.contains(cat);
                                return FilterChip(
                                  label: Text(
                                      _categoryLabel(cat, customCategories)),
                                  selected: selected,
                                  onSelected: (_) => setSheetState(() {
                                    if (selected) {
                                      localCategories = {
                                        ...localCategories,
                                      }..remove(cat);
                                    } else {
                                      localCategories = {
                                        ...localCategories,
                                        cat,
                                      };
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (memberMap.isNotEmpty) ...[
                            Text(
                              '付款人',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('全部'),
                                  selected: localPayer == null,
                                  onSelected: (_) =>
                                      setSheetState(() => localPayer = null),
                                ),
                                ...memberMap.entries.map((e) => ChoiceChip(
                                      label: Text(e.value),
                                      selected: localPayer == e.key,
                                      onSelected: (_) => setSheetState(
                                          () => localPayer = e.key),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            '日期範圍',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading:
                                  const Icon(Icons.date_range_outlined),
                              title: Text(
                                localDateRange != null
                                    ? '${DateFormat('MM/dd').format(localDateRange!.start)} － ${DateFormat('MM/dd').format(localDateRange!.end)}'
                                    : '不限日期',
                                style: localDateRange != null
                                    ? Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500)
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                              trailing: localDateRange != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 18),
                                      onPressed: () => setSheetState(
                                          () => localDateRange = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  initialDateRange: localDateRange,
                                );
                                if (picked != null) {
                                  setSheetState(
                                      () => localDateRange = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton(
                      onPressed: applyAndClose,
                      child: const Text('套用篩選'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleShareLink(BuildContext context) async {
    setState(() => _isSharing = true);
    final useCase = ref.read(createShareLinkUseCaseProvider);
    final result = await useCase(groupId);
    if (!mounted) return;
    setState(() => _isSharing = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗：${failure.message}')),
        );
      },
      (token) {
        final url = '${AppConstants.shareDomain}/s/$token';
        Share.share(url);
      },
    );
  }

  Future<void> _onRefresh() async {
    if (ref.read(isOnlineProvider)) {
      await ref.read(syncServiceProvider).flush();
    }
    ref.invalidate(expensesProvider(groupId));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      ref.listen(realtimeGroupMembersProvider(groupId), (prev, next) {});
    }
    ref.listen(realtimeExpensesProvider(groupId), (prev, next) {});

    final isGuest = ref.watch(isGuestProvider);
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final pendingCount = ref.watch(pendingCountProvider);
    final isArchived = groupAsync.valueOrNull?.isArchived ?? false;

    return PopScope(
      canPop: !isGuest,
      child: Scaffold(
        floatingActionButton: isGuest
            ? null
            : FloatingActionButton(
                onPressed: () =>
                    context.push('/groups/$groupId/add-expense'),
                child: const Icon(Icons.add),
              ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _buildScrollContent(context, isGuest, isArchived),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollContent(
      BuildContext context, bool isGuest, bool isArchived) {
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final customCategories =
        ref.watch(groupCategoriesProvider(groupId)).valueOrNull ?? [];
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final pendingCount = ref.watch(pendingCountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;
    final headerBg = Theme.of(context).colorScheme.surfaceContainerHigh;
    final groupValue = groupAsync.valueOrNull;

    // 提前計算總額供固定列使用
    final expensesRaw = expensesAsync.valueOrNull ?? [];
    final filteredExpenses = _applyFilters(expensesRaw);
    final groupTotal =
        filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final groupCurrency =
        expensesRaw.isNotEmpty ? expensesRaw.first.currency : '';

    // 計算欠款區固定高度（供 SliverPersistentHeader 使用）
    final myDebts = currentUserId != null
        ? ref
            .watch(simplifiedDebtsProvider(groupId))
            .where((d) =>
                d.fromUserId == currentUserId ||
                d.toUserId == currentUserId)
            .toList()
        : <SimplifiedDebtEntity>[];
    // divider(1) + padV(12+12) + content + divider(1)
    // settled: 28px row → 54px total
    // expanded: title(28) + gap(8) + N×28px → 62 + N×28
    // collapsed: title row only → 54px
    final debtSectionHMax = (isOnline && groupValue != null)
        ? (myDebts.isEmpty ? 54.0 : 62.0 + myDebts.length * 28.0)
        : 0.0;
    final debtSectionH = (isOnline && groupValue != null)
        ? (myDebts.isEmpty
            ? 54.0
            : _debtExpanded
                ? debtSectionHMax
                : 54.0)
        : 0.0;
    // 折疊欠款區時省下的高度，補回消費列表底部，維持 maxScrollExtent 不變
    final scrollCompensation = debtSectionHMax - debtSectionH;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── 固定導覽列（標題隨 header 捲走後淡入）────────────────────
        SliverAppBar(
          pinned: true,
          backgroundColor: headerBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !isGuest,
          title: AnimatedOpacity(
            opacity: _headerCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: groupAsync.maybeWhen(
              data: (group) => Text(group.name),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          actions: [
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '待同步 $pendingCount 筆',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ),
                ),
              ),
            if (isGuest)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: const Text('唯讀'),
                  labelStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.visibility_outlined, size: 14),
                ),
              )
            else
              groupAsync.whenOrNull(
                    data: (group) => group.isArchived
                        ? Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Chip(
                              label: const Text('已封存'),
                              labelStyle: const TextStyle(fontSize: 12),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(
                                  Icons.archive_outlined, size: 14),
                            ),
                          )
                        : null,
                  ) ??
                  const SizedBox.shrink(),
            if (!isGuest)
              IconButton(
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_outlined),
                tooltip: '分享群組',
                onPressed:
                    _isSharing ? null : () => _handleShareLink(context),
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '群組設定',
              onPressed: () => context.push('/groups/$groupId/settings'),
            ),
          ],
        ),

        // ── 群組標題 Header（隨 list 捲動消失）───────────────────────
        SliverToBoxAdapter(
          child: groupAsync.when(
            loading: () => _buildHeaderSkeleton(context),
            error: (_, __) => const SizedBox.shrink(),
            data: (group) => _buildHeaderContent(context, group),
          ),
        ),

        // ── 欠款資訊區（固定不捲動） ──────────────────────────────────
        if (debtSectionH > 0)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyDelegate(
              height: debtSectionH,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: _DebtSummary(
                          groupId: groupId,
                          currency: groupValue!.currency,
                          expanded: _debtExpanded,
                          onToggle: () =>
                              setState(() => _debtExpanded = !_debtExpanded),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ),
          ),

        // ── 固定列：消費總額 + 搜尋/過濾 ──────────────────────────────
        SliverAppBar(
          pinned: true,
          primary: false,
          automaticallyImplyLeading: false,
          toolbarHeight: 68,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasActiveFilters ? '篩選結果' : '群組消費總額',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      groupCurrency.isEmpty
                          ? '—'
                          : '$groupCurrency ${groupTotal.toStringAsFixed(0)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (groupCurrency.isNotEmpty)
                  Text(
                    '${filteredExpenses.length} 筆',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                      _showSearch ? Icons.search_off : Icons.search),
                  tooltip: '搜尋',
                  onPressed: _toggleSearch,
                ),
                Badge(
                  isLabelVisible: _advancedFilterCount > 0,
                  label: Text('$_advancedFilterCount'),
                  child: IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: '篩選',
                    onPressed: () => _showFilterSheet(context),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          bottom: _showSearch
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                )
              : null,
        ),

        // Expense content
        ...expensesAsync.when<List<Widget>>(
          loading: () => [
            const SliverFillRemaining(
              child: ExpenseListSkeleton(),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              child: AppErrorWidget(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(expensesProvider(groupId)),
              ),
            ),
          ],
          data: (expenses) {
            if (expenses.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: '尚無消費紀錄',
                    subtitle: '點擊 + 新增第一筆消費',
                  ),
                ),
              ];
            }

            final members = membersAsync.valueOrNull ?? [];
            final memberMap = buildResolvedMemberMap(members);

            // Build date groups
            final groups = <_DateGroup>[];
            String? lastDateKey;
            List<ExpenseEntity> currentExpenses = [];
            double dailySubtotal = 0;
            for (final expense in filteredExpenses) {
              final dateKey = _formatDateKey(expense.expenseDate);
              if (dateKey != lastDateKey) {
                if (lastDateKey != null) {
                  groups.add(_DateGroup(
                      lastDateKey, dailySubtotal, [...currentExpenses]));
                }
                currentExpenses = [];
                dailySubtotal = 0;
                lastDateKey = dateKey;
              }
              dailySubtotal += expense.amount;
              currentExpenses.add(expense);
            }
            if (lastDateKey != null) {
              groups.add(
                  _DateGroup(lastDateKey, dailySubtotal, currentExpenses));
            }

            if (filteredExpenses.isEmpty) {
              return [
                SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '沒有符合條件的消費',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('清除篩選'),
                      ),
                    ],
                  ),
                ),
              ];
            }

            return [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + scrollCompensation),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 16,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                group.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '$groupCurrency ${group.subtotal.toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: group.expenses
                                .map((expense) => ExpenseCard(
                                      expense: expense,
                                      paidByName:
                                          memberMap[expense.paidBy],
                                      customCategories: customCategories,
                                      showCard: false,
                                      onTap: expense.isPending
                                          ? null
                                          : () => context.push(
                                                '/groups/$groupId/expenses/${expense.id}',
                                              ),
                                      onLongPress: expense.isPending ||
                                              isGuest ||
                                              isArchived
                                          ? null
                                          : () => _showExpenseActions(
                                              context, expense),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  // ── Header Content Helpers ─────────────────────────────────────────────────

  Widget _buildHeaderContent(BuildContext context, dynamic group) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: cs.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '${group.type.label} · ${group.currency}',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: group.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邀請碼已複製')),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.key_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '邀請碼：${group.inviteCode}',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 200, height: 30, borderRadius: 4),
          SizedBox(height: 6),
          SkeletonBox(width: 130, height: 16, borderRadius: 4),
          SizedBox(height: 14),
          SkeletonBox(width: 160, height: 34, borderRadius: 8),
        ],
      ),
    );
  }
}

class _DebtSummary extends ConsumerWidget {
  const _DebtSummary({
    required this.groupId,
    required this.currency,
    required this.expanded,
    required this.onToggle,
  });

  final String groupId;
  final String currency;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;
    final debtsAsync = ref.watch(balancesProvider(groupId));

    if (debtsAsync.isLoading || currentUserId == null) {
      return const SizedBox.shrink();
    }

    final simplifiedDebts = ref.watch(simplifiedDebtsProvider(groupId));
    final myDebts = simplifiedDebts
        .where((d) =>
            d.fromUserId == currentUserId || d.toUserId == currentUserId)
        .toList();

    final defaultStyle = Theme.of(context).textTheme.bodyLarge;
    final amountStyle = defaultStyle?.copyWith(
      color: Theme.of(context).colorScheme.error,
      fontWeight: FontWeight.w600,
    );
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // 已結清：單行，無摺疊
    if (myDebts.isEmpty) {
      return InkWell(
        onTap: () => context.push('/groups/$groupId/balances'),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('帳目已結清',
                style: defaultStyle?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 標題列（點擊折疊/展開）
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text('帳務',
                  style:
                      defaultStyle?.copyWith(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${myDebts.length} 筆',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: mutedColor)),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: expanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_less, size: 20, color: mutedColor),
              ),
            ],
          ),
        ),
        // 欠款列表
        if (expanded) ...[
          const SizedBox(height: 8),
          ...myDebts.map((debt) {
            final isIOwe = debt.fromUserId == currentUserId;
            final amountStr = '$currency ${debt.amount.toStringAsFixed(0)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => context.push('/groups/$groupId/balances'),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: isIOwe
                      ? [
                          Text('你欠 ', style: defaultStyle),
                          Expanded(
                            child: Text(debt.toDisplayName,
                                style: defaultStyle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                          const SizedBox(width: 8),
                          Text(amountStr, style: amountStyle),
                        ]
                      : [
                          Expanded(
                            child: Text(debt.fromDisplayName,
                                style: defaultStyle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                          Text(' 欠你 ', style: defaultStyle),
                          Text(amountStr, style: amountStyle),
                        ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '搜尋消費描述…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sticky delegate ──────────────────────────────────────────────────────────

class _StickyDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_StickyDelegate old) =>
      old.height != height || old.child != child;
}

// ─── Date grouping helpers ────────────────────────────────────────────────────

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

String _formatDateKey(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  final weekday = _weekdays[date.weekday - 1];
  final formatted = DateFormat('MM/dd').format(date);

  if (diff == 0) return '今天  $formatted';
  if (diff == 1) return '昨天  $formatted';
  if (date.year == now.year) return '$formatted  星期$weekday';
  return '${DateFormat('yyyy/MM/dd').format(date)}  星期$weekday';
}

class _DateGroup {
  _DateGroup(this.label, this.subtotal, this.expenses);
  final String label;
  final double subtotal;
  final List<ExpenseEntity> expenses;
}
