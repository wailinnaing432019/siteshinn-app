import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/settlement_summary.dart';
import '../../services/analytics_service.dart';

class CategoryDonutChartCard extends StatefulWidget {
  final String title;
  final List<CategorySlice> slices;
  final double totalAmount;
  final String currencyCode;
  final AppStrings strings;

  const CategoryDonutChartCard({
    super.key,
    required this.title,
    required this.slices,
    required this.totalAmount,
    required this.currencyCode,
    required this.strings,
  });

  @override
  State<CategoryDonutChartCard> createState() => _CategoryDonutChartCardState();
}

class _CategoryDonutChartCardState extends State<CategoryDonutChartCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final colorScheme = Theme.of(context).colorScheme;
    final strings = widget.strings;

    if (slices.isEmpty) {
      return _EmptyChartCard(title: widget.title, message: strings.noChartData);
    }

    final selectedSlice =
        (_touchedIndex >= 0 && _touchedIndex < slices.length)
            ? slices[_touchedIndex]
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              strings.tapSliceHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 205,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 56,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            return;
                          }
                          final idx =
                              response.touchedSection!.touchedSectionIndex;
                          setState(() {
                            _touchedIndex = (_touchedIndex == idx) ? -1 : idx;
                          });
                        },
                      ),
                      sections: List.generate(slices.length, (i) {
                        final s = slices[i];
                        final isTouched = i == _touchedIndex;
                        final pct = (s.ratio * 100).toStringAsFixed(0);
                        return PieChartSectionData(
                          color: s.color,
                          value: s.amount,
                          radius: isTouched ? 48 : 40,
                          title: s.ratio >= 0.08 ? '$pct%' : '',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedSlice != null
                              ? strings.categoryName(selectedSlice.category)
                              : strings.totalSpent,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.formatAmount(
                            selectedSlice?.amount ?? widget.totalAmount,
                            widget.currencyCode,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...slices.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final isSelected = idx == _touchedIndex;
              final pct = (s.ratio * 100).toStringAsFixed(1);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _touchedIndex = isSelected ? -1 : idx;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? s.color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.categoryName(s.category),
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppFormatters.formatAmount(
                          s.amount,
                          widget.currencyCode,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class MemberPaidVsShareBarCard extends StatelessWidget {
  final List<MemberBalance> balances;
  final String currencyCode;
  final AppStrings strings;

  const MemberPaidVsShareBarCard({
    super.key,
    required this.balances,
    required this.currencyCode,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (balances.isEmpty) {
      return _EmptyChartCard(
        title: strings.paidVsShareChartTitle,
        message: strings.noChartData,
      );
    }

    var maxVal = 0.0;
    for (final b in balances) {
      maxVal = math.max(maxVal, math.max(b.totalPaid, b.totalShare));
    }
    final chartMaxY = maxVal <= 0 ? 100.0 : maxVal * 1.22;

    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 64,
      balances.length * 72.0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.paidVsShareChartTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendDot(
                  color: colorScheme.primary,
                  label: strings.totalPaid,
                ),
                _LegendDot(
                  color: const Color(0xFFF59E0B),
                  label: strings.fairShare,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: chartMaxY,
                    minY: 0,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: chartMaxY / 4,
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIdx, rod, rodIdx) {
                          final b = balances[group.x];
                          return BarTooltipItem(
                            '${b.member.name}\n'
                            '${strings.totalPaid}: ${AppFormatters.formatAmount(b.totalPaid, currencyCode)}\n'
                            '${strings.fairShare}: ${AppFormatters.formatAmount(b.totalShare, currencyCode)}\n'
                            '${AppFormatters.formatSignedAmount(b.netBalance, currencyCode)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: chartMaxY / 4,
                          getTitlesWidget: (value, meta) => Text(
                            AnalyticsService.formatCompactAxis(value),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= balances.length) {
                              return const SizedBox.shrink();
                            }
                            final name = balances[idx].member.name;
                            final shortName = name.length > 8
                                ? '${name.substring(0, 7)}…'
                                : name;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                shortName,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(balances.length, (i) {
                      final b = balances[i];
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: b.totalPaid,
                            width: 14,
                            color: colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: b.totalShare,
                            width: 14,
                            color: const Color(0xFFF59E0B),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncomeExpenseBarCard extends StatelessWidget {
  final double income;
  final double expense;
  final String currencyCode;
  final AppStrings strings;

  const IncomeExpenseBarCard({
    super.key,
    required this.income,
    required this.expense,
    required this.currencyCode,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxVal = math.max(income, expense);
    final chartMaxY = maxVal <= 0 ? 100.0 : maxVal * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.incomeVsExpenseTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 175,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceEvenly,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        final label = group.x == 0
                            ? strings.incomeLabel
                            : strings.expenseLabel;
                        return BarTooltipItem(
                          '$label\n${AppFormatters.formatAmount(rod.toY, currencyCode)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: chartMaxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          AnalyticsService.formatCompactAxis(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            v.toInt() == 0
                                ? strings.incomeLabel
                                : strings.expenseLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: income,
                          width: 36,
                          color: AppTheme.positiveGreen,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: expense,
                          width: 36,
                          color: AppTheme.negativeRed,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
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
}

class DailyTrendLineCard extends StatelessWidget {
  final String title;
  final List<DailyTrendPoint> points;
  final String currencyCode;
  final bool showIncome;
  final AppStrings strings;

  const DailyTrendLineCard({
    super.key,
    required this.title,
    required this.points,
    required this.currencyCode,
    this.showIncome = false,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return _EmptyChartCard(title: title, message: strings.noChartData);
    }

    var maxY = 0.0;
    for (final p in points) {
      maxY = math.max(maxY, p.expense);
      if (showIncome) {
        maxY = math.max(maxY, p.income);
      }
    }
    final chartMaxY = maxY <= 0 ? 100.0 : maxY * 1.25;
    final step = math.max(1, (points.length / 4).ceil());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (showIncome) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                children: [
                  _LegendDot(
                    color: AppTheme.negativeRed,
                    label: strings.expenseLabel,
                  ),
                  _LegendDot(
                    color: AppTheme.positiveGreen,
                    label: strings.incomeLabel,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 195,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(0, points.length - 1).toDouble(),
                  minY: 0,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final idx = spot.x.toInt().clamp(0, points.length - 1);
                          final dayStr = AppFormatters.formatShortDate(
                            points[idx].day,
                          );
                          final isIncomeLine = showIncome && spot.barIndex == 1;
                          final label = isIncomeLine
                              ? strings.incomeLabel
                              : strings.expenseLabel;
                          return LineTooltipItem(
                            '$dayStr • $label\n${AppFormatters.formatAmount(spot.y, currencyCode)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: chartMaxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          AnalyticsService.formatCompactAxis(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 ||
                              idx >= points.length ||
                              (idx % step != 0 && idx != points.length - 1)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              AppFormatters.formatShortDate(points[idx].day),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        points.length,
                        (i) => FlSpot(i.toDouble(), points[i].expense),
                      ),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: showIncome
                          ? AppTheme.negativeRed
                          : colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: points.length <= 12),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (showIncome
                                ? AppTheme.negativeRed
                                : colorScheme.primary)
                            .withValues(alpha: 0.14),
                      ),
                    ),
                    if (showIncome)
                      LineChartBarData(
                        spots: List.generate(
                          points.length,
                          (i) => FlSpot(i.toDouble(), points[i].income),
                        ),
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: AppTheme.positiveGreen,
                        barWidth: 3,
                        dotData: FlDotData(show: points.length <= 12),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.positiveGreen.withValues(alpha: 0.10),
                        ),
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
}

class CycleTrendChartCard extends StatelessWidget {
  final List<CycleTrendPoint> points;
  final String currencyCode;
  final AppStrings strings;

  const CycleTrendChartCard({
    super.key,
    required this.points,
    required this.currencyCode,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return _EmptyChartCard(
        title: strings.cycleTrendTitle,
        message: strings.noChartData,
      );
    }

    var maxVal = 0.0;
    for (final p in points) {
      maxVal = math.max(maxVal, p.totalExpense);
    }
    final chartMaxY = maxVal <= 0 ? 100.0 : maxVal * 1.25;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.cycleTrendTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 185,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        final p = points[group.x];
                        return BarTooltipItem(
                          '${strings.displayCycleTitle(p.cycle)}\n'
                          '${AppFormatters.formatAmount(p.totalExpense, currencyCode)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: chartMaxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          AnalyticsService.formatCompactAxis(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final title =
                              strings.displayCycleTitle(points[idx].cycle);
                          final shortTitle = title.length > 9
                              ? '${title.substring(0, 8)}…'
                              : title;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortTitle,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(points.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].totalExpense,
                          width: 22,
                          color: colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyChartCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
