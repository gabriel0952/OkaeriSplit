import 'package:app/core/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A slim banner shown at the top of screens when the device is offline.
/// Drop it inside a Column above the screen's main content.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();

    return Material(
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '目前離線，顯示快取資料',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
