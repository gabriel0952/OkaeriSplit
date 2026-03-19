import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/expenses/domain/entities/expense_stats_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_stats_provider.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseStatsScreen extends ConsumerWidget {
  const ExpenseStatsScreen({super.key, required this.groupId});

  final String groupId;

  // Curated palette — designed to look good in both light and dark mode
  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  Color _color(int i) => _palette[i % _palette.length];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final currency =
        ref.watch(groupDetailProvider(groupId)).valueOrNull?.currency ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('消費統計')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: expensesAsync.when(
              loading: () => const AppLoadingWidget(),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (_) {
                final categoryStats =
                    ref.watch(categoryStatsProvider(groupId));
                final monthlyStats = ref.watch(monthlyStatsProvider(groupId));

                if (categoryStats.isEmpty && monthlyStats.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.bar_chart_outlined,
                    title: '尚無消費紀錄',
                    subtitle: '新增消費後即可查看統計',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (categoryStats.isNotEmpty) ...[
                      _sectionTitle(context, '分類佔比'),
                      const SizedBox(height: 8),
                      _buildDonutCard(context, categoryStats, currency),
                      const SizedBox(height: 20),
                      _sectionTitle(context, '分類明細'),
                      const SizedBox(height: 8),
                      _buildCategoryDetailCard(
                          context, categoryStats, currency),
                      const SizedBox(height: 20),
                    ],
                    if (monthlyStats.isNotEmpty) ...[
                      _sectionTitle(context, '月度趨勢'),
                      const SizedBox(height: 8),
                      _buildBarCard(context, monthlyStats, currency),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  // ─── Donut chart ──────────────────────────────────────────────────────────

  Widget _buildDonutCard(
    BuildContext context,
    List<CategoryStatEntity> stats,
    String currency,
  ) {
    final total = stats.fold(0.0, (sum, s) => sum + s.totalAmount);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: stats.asMap().entries.map((e) {
                        return PieChartSectionData(
                          value: e.value.totalAmount,
                          title: '',
                          color: _color(e.key),
                          radius: 62,
                        );
                      }).toList(),
                      centerSpaceRadius: 54,
                      sectionsSpace: 3,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '總計',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$currency ${total.toStringAsFixed(0)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: stats.asMap().entries.map((e) {
                final color = _color(e.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      e.value.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category detail list ─────────────────────────────────────────────────

  Widget _buildCategoryDetailCard(
    BuildContext context,
    List<CategoryStatEntity> stats,
    String currency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: stats.asMap().entries.map((e) {
            final i = e.key;
            final stat = e.value;
            final color = _color(i);
            final isLast = i == stats.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          categoryIcon(stat.category, []),
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stat.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$currency ${stat.totalAmount.toStringAsFixed(0)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: stat.percentage / 100,
                                color: color,
                                backgroundColor:
                                    color.withValues(alpha: 0.12),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${stat.percentage.toStringAsFixed(1)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 66),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Monthly bar chart ────────────────────────────────────────────────────

  Widget _buildBarCard(
    BuildContext context,
    List<MonthlyStatEntity> stats,
    String currency,
  ) {
    final maxAmount =
        stats.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAmount * 1.35,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      colorScheme.surfaceContainerHighest,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '$currency ${rod.toY.toStringAsFixed(0)}',
                    TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= stats.length) {
                        return const SizedBox.shrink();
                      }
                      final month =
                          int.tryParse(stats[idx].yearMonth.substring(5)) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$month月',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              barGroups: stats.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.totalAmount,
                      color: colorScheme.primary,
                      width: 18,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
