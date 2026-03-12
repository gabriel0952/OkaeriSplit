import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────
// SkeletonBox — single shimmer tile
// ──────────────────────────────────────────────────────────────

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF2F2F7);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// ExpenseListSkeleton — 5 skeleton rows matching ExpenseCard
// ──────────────────────────────────────────────────────────────

class ExpenseListSkeleton extends StatelessWidget {
  const ExpenseListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card placeholder
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SkeletonBox(width: 24, height: 24, borderRadius: 4),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 60, height: 10, borderRadius: 4),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 20, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SkeletonBox(width: 80, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Column(
              children: List.generate(5, (i) => _SkeletonExpenseRow(isLast: i == 4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonExpenseRow extends StatelessWidget {
  const _SkeletonExpenseRow({required this.isLast});
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SkeletonBox(width: 44, height: 44, borderRadius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 10, borderRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SkeletonBox(width: 60, height: 16, borderRadius: 4),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 74,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// GroupListSkeleton — 3 skeleton cards matching GroupCard
// ──────────────────────────────────────────────────────────────

class GroupListSkeleton extends StatelessWidget {
  const GroupListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SkeletonBox(width: 48, height: 48, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 15, borderRadius: 4),
                      const SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                SkeletonBox(width: 24, height: 24, borderRadius: 4),
              ],
            ),
          ),
        )),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// BalanceSkeleton — summary card + 2 debt rows
// ──────────────────────────────────────────────────────────────

class BalanceSkeleton extends StatelessWidget {
  const BalanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card placeholder
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 80, height: 12, borderRadius: 4),
                const SizedBox(height: 10),
                SkeletonBox(width: 140, height: 28, borderRadius: 6),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 50, height: 10, borderRadius: 4),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 14, borderRadius: 4),
                      ],
                    )),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 50, height: 10, borderRadius: 4),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 14, borderRadius: 4),
                      ],
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SkeletonBox(width: 80, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Column(
              children: List.generate(2, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, borderRadius: 18),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 14, borderRadius: 4)),
                    const SizedBox(width: 12),
                    SkeletonBox(width: 60, height: 14, borderRadius: 4),
                  ],
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
