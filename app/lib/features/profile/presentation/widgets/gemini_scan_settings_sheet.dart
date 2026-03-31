import 'package:app/features/expenses/presentation/providers/gemini_scan_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiScanSettingsSheet extends ConsumerStatefulWidget {
  const GeminiScanSettingsSheet({super.key, required this.maskedApiKey});

  final String? maskedApiKey;

  @override
  ConsumerState<GeminiScanSettingsSheet> createState() =>
      _GeminiScanSettingsSheetState();
}

class _GeminiScanSettingsSheetState
    extends ConsumerState<GeminiScanSettingsSheet> {
  late final TextEditingController _controller;
  bool _saving = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 Gemini API key')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(geminiScanSettingsControllerProvider).saveApiKey(value);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存 Gemini API key 失敗')));
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref.read(geminiScanSettingsControllerProvider).deleteApiKey();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('刪除 Gemini API key 失敗')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gemini 掃描設定',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            '此 API key 只會保存在這台裝置上，並在你使用 Gemini 掃描時才會被送往 Okaeri 代理呼叫。Gemini usage 將消耗你自己的 API key 配額與費用。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.maskedApiKey != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('目前已設定：${widget.maskedApiKey}'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Gemini API key',
              hintText: '貼上新的 API key',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureText = !_obscureText),
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(widget.maskedApiKey == null ? '儲存' : '更新'),
                ),
              ),
              if (widget.maskedApiKey != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    child: const Text('刪除'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
