import 'dart:io';

import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/domain/entities/gemini_scan_extras_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/presentation/providers/receipt_scan_provider.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Data returned to AddExpenseScreen after user confirms import.
class ReceiptImportData {
  const ReceiptImportData({
    required this.items,
    required this.total,
    required this.imageFile,
    this.currency,
    this.merchant,
    this.date,
    this.itemMemberIds = const [],
  });

  final List<ScanResultItemEntity> items;
  final double total;
  final File imageFile;

  /// Selected currency, null = keep AddExpenseScreen's current currency.
  final String? currency;

  /// Merchant / store name extracted by Gemini, null if not available.
  final String? merchant;

  /// Purchase date extracted by Gemini, null if not available.
  final DateTime? date;

  /// Per-item member assignment (parallel to [items]).
  /// Empty set = all members (default).
  final List<Set<String>> itemMemberIds;
}

class ReceiptScanResultScreen extends ConsumerStatefulWidget {
  const ReceiptScanResultScreen({
    super.key,
    required this.imageFile,
    required this.method,
    this.language = OcrLanguage.auto,
    this.members = const [],
    this.availableCurrencies = const [],
    this.initialCurrency,
    this.groupId,
  });

  final File imageFile;
  final ReceiptScanMethod method;
  final OcrLanguage language;

  /// Group members for per-item assignment. Empty = hide member UI.
  final List<GroupMemberEntity> members;

  /// Currencies the user can pick for this receipt.
  final List<String> availableCurrencies;

  /// Pre-selected currency (the group / expense currency).
  final String? initialCurrency;

  /// Group ID used to navigate to group settings for exchange-rate setup.
  final String? groupId;

  @override
  ConsumerState<ReceiptScanResultScreen> createState() =>
      _ReceiptScanResultScreenState();
}

class _ReceiptScanResultScreenState
    extends ConsumerState<ReceiptScanResultScreen> {
  List<ScanResultItemEntity> _items = [];
  List<ScanResultItemEntity> _originalItems = [];
  double _originalTotal = 0;
  bool _excludeTax = false;
  List<UniqueKey> _itemKeys = [];
  List<Set<String>> _itemMemberIds = [];
  double _total = 0;
  bool _totalManuallyEdited = false;
  bool _lowConfidence = false;
  String? _currency;
  GeminiScanExtras? _geminiExtras;
  final _totalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rescan();
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Set<String> get _allMemberIds => widget.members.map((m) => m.userId).toSet();

  void _onScanResult(ScanResultEntity result) {
    setState(() {
      _originalItems = List.of(result.items);
      _originalTotal = result.total;
      _excludeTax = false;
      _items = List.of(result.items);
      _itemKeys = List.generate(_items.length, (_) => UniqueKey());
      _itemMemberIds = List.generate(
        _items.length,
        (_) => Set.of(_allMemberIds),
      );
      _total = result.total;
      _totalController.text = _total > 0 ? _total.toStringAsFixed(0) : '';
      _totalManuallyEdited = false;
      _lowConfidence = result.lowConfidence;
      _geminiExtras = result.geminiExtras;
      // Auto-apply currency detected by Gemini if the user hasn't overridden it.
      if (_currency == widget.initialCurrency &&
          result.geminiExtras?.currency != null) {
        _currency = result.geminiExtras!.currency;
      }
    });
  }

  /// Applies or removes tax exclusion from item amounts and total.
  void _applyTaxExclusion(bool exclude) {
    final taxType = _geminiExtras?.taxType;
    final isIncluded = taxType == GeminiTaxType.included;

    setState(() {
      _excludeTax = exclude;

      if (isIncluded) {
        _items = exclude
            ? _originalItems.map((item) {
                final tax = item.itemTaxAmount ?? 0.0;
                return item.copyWith(
                  amount: (item.amount - tax).clamp(0.0, double.infinity),
                );
              }).toList()
            : List.of(_originalItems);
        final sum = _items.fold(0.0, (s, e) => s + e.amount);
        _total = sum;
        _totalController.text = sum > 0 ? sum.toStringAsFixed(0) : '';
        _totalManuallyEdited = false;
      } else {
        // 外税: items already hold pre-tax amounts; only the total changes.
        _items = List.of(_originalItems);
        if (exclude) {
          final sum = _items.fold(0.0, (s, e) => s + e.amount);
          _total = sum;
          _totalController.text = sum > 0 ? sum.toStringAsFixed(0) : '';
          _totalManuallyEdited = false;
        } else {
          _total = _originalTotal;
          _totalController.text =
              _originalTotal > 0 ? _originalTotal.toStringAsFixed(0) : '';
          _totalManuallyEdited = true;
        }
      }
    });
  }

  void _recalculateTotal() {
    if (!_totalManuallyEdited) {
      final sum = _items.fold(0.0, (s, item) => s + item.amount);
      setState(() {
        _total = sum;
        _totalController.text = sum > 0 ? sum.toStringAsFixed(0) : '';
      });
    }
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      _itemKeys.removeAt(index);
      _itemMemberIds.removeAt(index);
    });
    _recalculateTotal();
  }

  void _addEmptyItem() {
    setState(() {
      _items.insert(0, const ScanResultItemEntity(name: '', amount: 0));
      _itemKeys.insert(0, UniqueKey());
      _itemMemberIds.insert(0, Set.of(_allMemberIds));
    });
  }

  void _updateItem(int index, ScanResultItemEntity updated) {
    setState(() => _items[index] = updated);
    _recalculateTotal();
  }

  void _updateItemMembers(int index, Set<String> memberIds) {
    setState(() => _itemMemberIds[index] = memberIds);
  }

  void _import() {
    final total =
        double.tryParse(
          _totalController.text.replaceAll(RegExp(r'[,，]'), ''),
        ) ??
        _total;
    Navigator.of(context).pop(
      ReceiptImportData(
        items: _items,
        total: total,
        imageFile: widget.imageFile,
        currency: _currency,
        merchant: _geminiExtras?.merchant,
        date: _geminiExtras?.date,
        itemMemberIds: List.of(_itemMemberIds),
      ),
    );
  }

  void _showFullscreenPhoto() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) =>
          _FullscreenPhotoDialog(imageFile: widget.imageFile),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  void _rescan() => ref
      .read(receiptScanProvider.notifier)
      .scan(
        widget.imageFile,
        language: widget.language,
        method: widget.method,
        userId: ref.read(authStateProvider).valueOrNull?.id,
      );

  Future<void> _showCurrencyPicker() async {
    // Include any Gemini-detected currency that isn't in the configured list.
    final currencies = [
      ...widget.availableCurrencies,
      if (_currency != null && !widget.availableCurrencies.contains(_currency!))
        _currency!,
    ];
    if (currencies.length <= 1) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '選擇幣別',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...currencies.map(
              (c) => ListTile(
                title: Text(c),
                trailing: _currency == c
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _currency = c);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(receiptScanProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<ReceiptScanState>(receiptScanProvider, (prev, next) {
      if (next.status == ScanStatus.success && next.result != null) {
        _onScanResult(next.result!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描結果'),
        actions: [
          if (scanState.status != ScanStatus.scanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新掃描',
              onPressed: _rescan,
            ),
        ],
      ),
      body: _buildBody(scanState, colorScheme),
      bottomNavigationBar: scanState.status == ScanStatus.success
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.check),
                  label: const Text('匯入費用表單'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ReceiptScanState scanState, ColorScheme colorScheme) {
    return switch (scanState.status) {
      ScanStatus.notSupported => _buildNotSupported(scanState, colorScheme),
      ScanStatus.idle || ScanStatus.scanning => _buildLoading(colorScheme),
      ScanStatus.error => _buildError(scanState, colorScheme),
      ScanStatus.success => _buildResult(colorScheme),
    };
  }

  // ── State screens ──────────────────────────────────────────────────────────

  Widget _buildNotSupported(
    ReceiptScanState scanState,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smartphone_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              scanState.errorMessage ?? '此裝置目前不支援收據掃描',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '請在支援 Apple Vision 或 ML Kit OCR 的裝置上再試一次。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildPhotoPreview(colorScheme, dimmed: true),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          widget.method == ReceiptScanMethod.gemini
              ? '正在使用 Gemini 分析收據...'
              : '正在分析收據...',
          style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          '首次分析可能需要較長時間',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ReceiptScanState scanState, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              scanState.errorMessage ?? '辨識失敗',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _rescan,
              icon: const Icon(Icons.refresh),
              label: const Text('重新辨識'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result screen ──────────────────────────────────────────────────────────

  Widget _buildResult(ColorScheme colorScheme) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          // ── Photo preview ──────────────────────────────────────────────────
          _buildPhotoPreview(colorScheme),
          const SizedBox(height: 12),

          // ── Gemini extras (merchant / date / currency / tax / category) ────
          if (_geminiExtras != null) ...[
            _GeminiExtrasCard(extras: _geminiExtras!, colorScheme: colorScheme),
            const SizedBox(height: 10),
          ],

          // ── Low-confidence warning ─────────────────────────────────────────
          if (_lowConfidence) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '辨識結果可能不完整，請確認品項與金額後再匯入。',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Total + currency ───────────────────────────────────────────────
          _buildTotalCard(colorScheme),
          const SizedBox(height: 12),

          // ── Exchange-rate setup reminder ───────────────────────────────────
          if (_currency != null &&
              !widget.availableCurrencies.contains(_currency!) &&
              widget.groupId != null) ...[
            _buildExchangeRateWarning(colorScheme),
            const SizedBox(height: 10),
          ],

          // ── Items header ───────────────────────────────────────────────────
          Row(
            children: [
              Text(
                '品項 (${_items.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addEmptyItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增品項'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── Item cards ─────────────────────────────────────────────────────
          ...List.generate(_items.length, (index) {
            return _ItemCard(
              key: _itemKeys[index],
              item: _items[index],
              memberIds: _itemMemberIds[index],
              allMembers: widget.members,
              currency: _currency,
              onChanged: (updated) => _updateItem(index, updated),
              onMembersChanged: (ids) => _updateItemMembers(index, ids),
              onDelete: () => _deleteItem(index),
            );
          }),

          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '未辨識到品項，可手動新增',
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(ColorScheme colorScheme, {bool dimmed = false}) {
    return GestureDetector(
      onTap: dimmed ? null : _showFullscreenPhoto,
      child: Container(
        height: 220,
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              widget.imageFile,
              fit: BoxFit.cover,
              opacity: AlwaysStoppedAnimation(dimmed ? 0.4 : 1.0),
            ),
            if (!dimmed)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '點擊放大',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeRateWarning(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '幣別 $_currency 尚未在群組設定匯率，匯入後計算可能不正確。',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              context.push('/groups/${widget.groupId}/settings');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: colorScheme.onTertiaryContainer,
            ),
            child: const Text(
              '前往設定',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ColorScheme colorScheme) {
    // Show currency picker if there are multiple configured currencies OR if
    // Gemini detected a currency not yet in the configured list.
    final detectedNotInList =
        _currency != null && !widget.availableCurrencies.contains(_currency!);
    final hasCurrencyChoice =
        widget.availableCurrencies.length > 1 || detectedNotInList;

    // Show tax toggle only when Gemini reported a taxable type and a tax amount.
    final taxType = _geminiExtras?.taxType;
    final taxAmount = _geminiExtras?.taxAmount ?? 0;
    final showTaxToggle = taxType != null &&
        taxType != GeminiTaxType.exempt &&
        taxAmount > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '總金額',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_currency != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _currency!,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,，]')),
                    ],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _totalManuallyEdited = true;
                      final parsed = double.tryParse(
                        value.replaceAll(RegExp(r'[,，]'), ''),
                      );
                      if (parsed != null) {
                        setState(() => _total = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (hasCurrencyChoice) ...[
              const Divider(height: 20),
              InkWell(
                onTap: _showCurrencyPicker,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '幣別',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _currency ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (showTaxToggle) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '扣除稅金',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          taxType == GeminiTaxType.included
                              ? '内税 ${taxAmount.toStringAsFixed(0)} ${_currency ?? ''} 已含在品項金額中'
                              : '外税 ${taxAmount.toStringAsFixed(0)} ${_currency ?? ''} 加算於總金額',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _excludeTax,
                    onChanged: _applyTaxExclusion,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Item card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.memberIds,
    required this.allMembers,
    required this.onChanged,
    required this.onMembersChanged,
    required this.onDelete,
    this.currency,
  });

  final ScanResultItemEntity item;
  final Set<String> memberIds;
  final List<GroupMemberEntity> allMembers;
  final String? currency;
  final ValueChanged<ScanResultItemEntity> onChanged;
  final ValueChanged<Set<String>> onMembersChanged;
  final VoidCallback onDelete;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(
      text: widget.item.amount > 0
          ? widget.item.amount.toStringAsFixed(
              widget.item.amount == widget.item.amount.roundToDouble() ? 0 : 2,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[,，]'), ''),
        ) ??
        0;
    widget.onChanged(
      widget.item.copyWith(name: _nameController.text, amount: amount),
    );
  }

  String _memberLabel() {
    if (widget.allMembers.isEmpty) return '';
    final allIds = widget.allMembers.map((m) => m.userId).toSet();
    final selected = widget.memberIds;
    if (selected.isEmpty || selected.containsAll(allIds)) {
      return '全部 ${widget.allMembers.length} 人';
    }
    final names = widget.allMembers
        .where((m) => selected.contains(m.userId))
        .map((m) => m.displayName)
        .toList();
    if (names.length <= 2) return names.join('、');
    return '${names.take(2).join('、')} 等 ${names.length} 人';
  }

  Future<void> _showMemberPicker() async {
    final current = Set<String>.of(widget.memberIds);
    final allMembers = widget.allMembers;
    if (allMembers.isEmpty) return;

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MemberPickerSheet(
        allMembers: allMembers,
        selected: current,
        itemName: widget.item.name,
      ),
    );
    if (result != null) {
      widget.onMembersChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showMembers = widget.allMembers.isNotEmpty;

    return Dismissible(
      key: widget.key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            // ── Main row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        isDense: true,
                        hintText: '品項名稱',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      minLines: 1,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _notifyChange(),
                      onSubmitted: (_) => _notifyChange(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Amount + delete column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.item.quantity > 1)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'x${widget.item.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,，]'),
                                ),
                              ],
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                isDense: true,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _notifyChange(),
                              onSubmitted: (_) => _notifyChange(),
                            ),
                          ),
                          // Delete button
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Member row (visible when members exist) ───────────────────
            if (showMembers) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              InkWell(
                onTap: _showMemberPicker,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _memberLabel(),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Member picker bottom sheet ───────────────────────────────────────────────

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.allMembers,
    required this.selected,
    required this.itemName,
  });

  final List<GroupMemberEntity> allMembers;
  final Set<String> selected;
  final String itemName;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selected);
  }

  void _toggle(String userId) {
    setState(() {
      if (_selected.contains(userId)) {
        _selected.remove(userId);
      } else {
        _selected.add(userId);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == widget.allMembers.length) {
        _selected.clear();
      } else {
        _selected = widget.allMembers.map((m) => m.userId).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSelected = _selected.length == widget.allMembers.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '分攤成員',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (widget.itemName.isNotEmpty)
                          Text(
                            widget.itemName,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleAll,
                    child: Text(allSelected ? '取消全選' : '全選'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.allMembers.map((member) {
                  final isSelected = _selected.contains(member.userId);
                  final name = member.displayName;
                  return GestureDetector(
                    onTap: () => _toggle(member.userId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.6,
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: colorScheme.outlineVariant,
                                width: 1.5,
                              ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isSelected
                                ? Colors.white.withValues(alpha: 0.3)
                                : colorScheme.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('確認'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Fullscreen photo dialog with swipe-to-dismiss ────────────────────────────

class _FullscreenPhotoDialog extends StatefulWidget {
  const _FullscreenPhotoDialog({required this.imageFile});
  final File imageFile;

  @override
  State<_FullscreenPhotoDialog> createState() => _FullscreenPhotoDialogState();
}

class _FullscreenPhotoDialogState extends State<_FullscreenPhotoDialog> {
  final _transformController = TransformationController();
  double _dragY = 0;
  bool _dragging = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _isAtDefaultScale =>
      _transformController.value.getMaxScaleOnAxis() <= 1.05;

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isAtDefaultScale) setState(() => _dragY += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragY.abs() > 80 || (d.primaryVelocity ?? 0).abs() > 600) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragY = 0;
        _dragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - (_dragY.abs() / 280)).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
        color: Colors.black.withValues(alpha: bgOpacity),
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 6.0,
                  child: Image.file(widget.imageFile),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeminiExtrasCard extends StatelessWidget {
  const _GeminiExtrasCard({
    required this.extras,
    required this.colorScheme,
  });

  final GeminiScanExtras extras;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (extras.merchant != null) {
      rows.add(_row(Icons.store_outlined, '店家', extras.merchant!));
    }
    if (extras.date != null) {
      final d = extras.date!;
      rows.add(
        _row(
          Icons.calendar_today_outlined,
          '消費日期',
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
        ),
      );
    }
    if (extras.currency != null) {
      rows.add(_row(Icons.currency_exchange_outlined, '幣別', extras.currency!));
    }
    if (extras.taxAmount != null || extras.taxType != null) {
      final taxLabel = switch (extras.taxType) {
        GeminiTaxType.included => '内税',
        GeminiTaxType.excluded => '外税',
        GeminiTaxType.exempt => '免税',
        null => null,
      };
      final taxParts = [
        ?taxLabel,
        if (extras.taxAmount != null && extras.taxAmount! > 0)
          '${extras.taxAmount!.toStringAsFixed(0)} ${extras.currency ?? ''}',
      ];
      if (taxParts.isNotEmpty) {
        rows.add(
          _row(Icons.receipt_long_outlined, '稅金（參考）', taxParts.join(' · ')),
        );
      }
    }
    if (extras.suggestedCategory != null) {
      rows.add(
        _row(
          Icons.label_outline,
          '建議分類',
          extras.suggestedCategory!.label,
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemini 辨識資訊',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ...rows.expand((w) => [w, const SizedBox(height: 4)]).toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
