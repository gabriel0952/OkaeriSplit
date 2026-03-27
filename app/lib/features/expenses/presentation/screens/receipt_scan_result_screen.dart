import 'dart:io';

import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/presentation/providers/receipt_scan_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data returned to AddExpenseScreen after user confirms import.
class ReceiptImportData {
  const ReceiptImportData({
    required this.items,
    required this.total,
    required this.imageFile,
  });

  final List<ScanResultItemEntity> items;
  final double total;
  final File imageFile;
}

class ReceiptScanResultScreen extends ConsumerStatefulWidget {
  const ReceiptScanResultScreen({
    super.key,
    required this.imageFile,
  });

  final File imageFile;

  @override
  ConsumerState<ReceiptScanResultScreen> createState() =>
      _ReceiptScanResultScreenState();
}

class _ReceiptScanResultScreenState
    extends ConsumerState<ReceiptScanResultScreen> {
  List<ScanResultItemEntity> _items = [];
  double _total = 0;
  bool _totalManuallyEdited = false;
  final _totalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiptScanProvider.notifier).scan(widget.imageFile);
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  void _onScanResult(ScanResultEntity result) {
    setState(() {
      _items = List.of(result.items);
      _total = result.total;
      _totalController.text = _total > 0 ? _total.toStringAsFixed(0) : '';
      _totalManuallyEdited = false;
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
    setState(() => _items.removeAt(index));
    _recalculateTotal();
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(const ScanResultItemEntity(name: '', amount: 0));
    });
  }

  void _updateItem(int index, ScanResultItemEntity updated) {
    setState(() => _items[index] = updated);
    _recalculateTotal();
  }

  void _import() {
    final total = double.tryParse(
          _totalController.text.replaceAll(RegExp(r'[,，]'), ''),
        ) ??
        _total;
    Navigator.of(context).pop(
      ReceiptImportData(
        items: _items,
        total: total,
        imageFile: widget.imageFile,
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
          if (scanState.status == ScanStatus.error)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新掃描',
              onPressed: () =>
                  ref.read(receiptScanProvider.notifier).scan(widget.imageFile),
            ),
        ],
      ),
      body: _buildBody(scanState, colorScheme),
      bottomNavigationBar: scanState.status == ScanStatus.success
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ScanStatus.notSupported => _buildNotSupported(colorScheme),
      ScanStatus.idle || ScanStatus.scanning => _buildLoading(colorScheme),
      ScanStatus.error => _buildError(scanState, colorScheme),
      ScanStatus.success => _buildResult(colorScheme),
    };
  }

  Widget _buildNotSupported(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smartphone_outlined,
                size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(
              '此裝置不支援 AI 辨識功能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '收據掃描需要 iOS 18.1+（Apple Intelligence）\n或支援 Android AICore 的裝置。',
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
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: Image.file(
            widget.imageFile,
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.5),
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'AI 正在分析收據...',
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(receiptScanProvider.notifier).scan(widget.imageFile),
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

  Widget _buildResult(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        Container(
          height: 120,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: Image.file(widget.imageFile, fit: BoxFit.cover),
        ),

        // Total amount
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _totalController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,，]')),
                    ],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 24,
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
          ),
        ),
        const SizedBox(height: 8),

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

        ...List.generate(_items.length, (index) {
          return _ItemTile(
            key: ValueKey('item_$index'),
            item: _items[index],
            onChanged: (updated) => _updateItem(index, updated),
            onDelete: () => _deleteItem(index),
          );
        }),

        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '未辨識到品項，可手動新增',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final ScanResultItemEntity item;
  final ValueChanged<ScanResultItemEntity> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
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
    final amount = double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[,，]'), ''),
        ) ??
        0;
    widget.onChanged(
      widget.item.copyWith(
        name: _nameController.text,
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: widget.key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: '品項名稱',
                    hintStyle: TextStyle(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              if (widget.item.quantity > 1)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                width: 90,
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,，]')),
                  ],
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
