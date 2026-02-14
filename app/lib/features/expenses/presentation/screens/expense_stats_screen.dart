import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/expenses/domain/entities/expense_stats_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_stats_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseStatsScreen extends ConsumerWidget {
  const ExpenseStatsScreen({super.key, required this.groupId});

  final String groupId;

  static const _categoryColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('消費統計')),
      body: expensesAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (_) {
          final categoryStats = ref.watch(categoryStatsProvider(groupId));
          final monthlyStats = ref.watch(monthlyStatsProvider(groupId));

          if (categoryStats.isEmpty && monthlyStats.isEmpty) {
            return const Center(child: Text('尚無消費紀錄'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (categoryStats.isNotEmpty) ...[
                Text(
                  '分類佔比',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildPieChart(categoryStats),
                const SizedBox(height: 16),
                _buildCategoryLegend(context, categoryStats),
                const SizedBox(height: 32),
              ],
              if (monthlyStats.isNotEmpty) ...[
                Text(
                  '月度趨勢',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildBarChart(context, monthlyStats),
                const SizedBox(height: 32),
              ],
              if (categoryStats.isNotEmpty) ...[
                Text(
                  '分類明細',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildCategoryDetail(context, categoryStats),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPieChart(List<CategoryStatEntity> stats) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: stats.asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            return PieChartSectionData(
              value: stat.totalAmount,
              title: '${stat.percentage.toStringAsFixed(1)}%',
              color: _categoryColors[i % _categoryColors.length],
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(
    BuildContext context,
    List<CategoryStatEntity> stats,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: stats.asMap().entries.map((entry) {
        final i = entry.key;
        final stat = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _categoryColors[i % _categoryColors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              stat.category.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    List<MonthlyStatEntity> stats,
  ) {
    final maxAmount =
        stats.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '\$${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.length) {
                    return const SizedBox.shrink();
                  }
                  final label = stats[index].yearMonth.substring(5);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: stats.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.totalAmount,
                  color: Theme.of(context).colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryDetail(
    BuildContext context,
    List<CategoryStatEntity> stats,
  ) {
    return Card(
      child: Column(
        children: stats.asMap().entries.map((entry) {
          final i = entry.key;
          final stat = entry.value;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _categoryColors[i % _categoryColors.length],
              radius: 16,
              child: Text(
                stat.category.label.substring(0, 1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(stat.category.label),
            trailing: Text(
              '\$${stat.totalAmount.toStringAsFixed(0)} (${stat.percentage.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
