import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_icon.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/member.dart';
import '../../data/models/settlement_summary.dart';
import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/excel_export_service.dart';
import '../../services/export_file_opener.dart';
import '../../services/pdf_export_service.dart';
import '../widgets/account_charts.dart';
import '../widgets/export_sheet.dart';

class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final account = dashboard?.activeAccount;
    final report = dashboard?.currentReport;

    if (account == null || report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CycleReportView(
      account: account,
      report: report,
      allMembers: dashboard?.members ?? [],
      strings: strings,
      isOpenCycle: true,
      onCloseCycle: () async {
        final settledTitle = await showDialog<String>(
          context: context,
          builder: (_) => _CloseCycleDialog(strings: strings),
        );
        if (settledTitle != null && settledTitle.isNotEmpty) {
          await ref
              .read(dashboardProvider.notifier)
              .closeCurrentCycle(settledTitle);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.cycleSettledToast)),
            );
          }
        }
      },
    );
  }
}

class CycleReportView extends StatefulWidget {
  final Account account;
  final CycleSettlementReport report;
  final List<Member> allMembers;
  final AppStrings strings;
  final bool isOpenCycle;
  final Future<void> Function()? onCloseCycle;
  final Future<void> Function(String transferId, bool isPaid)?
      onToggleTransferPaid;

  const CycleReportView({
    super.key,
    required this.account,
    required this.report,
    required this.allMembers,
    required this.strings,
    required this.isOpenCycle,
    this.onCloseCycle,
    this.onToggleTransferPaid,
  });

  @override
  State<CycleReportView> createState() => _CycleReportViewState();
}

class _CycleReportViewState extends State<CycleReportView> {
  bool _isExporting = false;
  bool _showCharts = false;
  final Set<int> _expandedTransferIndices = <int>{};

  Future<void> _runExportSheet({
    required String title,
    required Future<void> Function() onShare,
    required Future<SavedExportResult?> Function() onSaveToDevice,
  }) async {
    setState(() => _isExporting = true);
    try {
      await showExportOptionsSheet(
        context: context,
        strings: widget.strings,
        title: title,
        onShare: onShare,
        onSaveToDevice: onSaveToDevice,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final report = widget.report;
    final currency = widget.account.currencyCode;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      strings.displayCycleTitle(report.cycle),
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppFormatters.formatDateRange(
                        report.cycle.startDate,
                        report.cycle.endDate,
                      ),
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                strings.totalSpent,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.formatAmount(report.totalExpense, currency),
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniStat(
                    label: strings.perPerson,
                    value: AppFormatters.formatAmount(
                      report.averagePerMember,
                      currency,
                    ),
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 24),
                  _MiniStat(
                    label: strings.expensesCount,
                    value: '${report.expenseCount}',
                    color: colorScheme.onPrimary,
                  ),
                  if (report.advanceCount > 0) ...[
                    const SizedBox(width: 24),
                    _MiniStat(
                      label: strings.advancesCountLabel,
                      value: '${report.advanceCount}',
                      color: colorScheme.onPrimary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Export Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _runExportSheet(
                          title: strings.exportPdf,
                          onShare: () => PdfExportService.shareCyclePdf(
                            account: widget.account,
                            report: report,
                            allMembers: widget.allMembers,
                            strings: strings,
                          ),
                          onSaveToDevice: () =>
                              PdfExportService.saveCyclePdfToDevice(
                            account: widget.account,
                            report: report,
                            allMembers: widget.allMembers,
                            strings: strings,
                          ),
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_isExporting ? strings.exporting : strings.exportPdf),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _runExportSheet(
                          title: strings.exportExcel,
                          onShare: () => ExcelExportService.shareCycleExcel(
                            account: widget.account,
                            report: report,
                            allMembers: widget.allMembers,
                            strings: strings,
                          ),
                          onSaveToDevice: () =>
                              ExcelExportService.saveCycleExcelToDevice(
                            account: widget.account,
                            report: report,
                            allMembers: widget.allMembers,
                            strings: strings,
                          ),
                        ),
                icon: const Icon(Icons.table_chart_outlined),
                label: Text(_isExporting ? strings.exporting : strings.exportExcel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SegmentedButton<bool>(
          segments: [
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.balance_outlined, size: 18),
              label: Text(strings.settlementTabLabel),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: Text(strings.chartsTabLabel),
            ),
          ],
          selected: {_showCharts},
          onSelectionChanged: (sel) {
            setState(() => _showCharts = sel.first);
          },
        ),
        const SizedBox(height: 16),

        if (_showCharts) ...[
          MemberPaidVsShareBarCard(
            balances: report.balances,
            currencyCode: currency,
            strings: strings,
          ),
          const SizedBox(height: 12),
          CategoryDonutChartCard(
            title: strings.categoryBreakdown,
            slices: AnalyticsService.computeCategoryBreakdown(report.expenses),
            totalAmount: report.totalExpense,
            currencyCode: currency,
            strings: strings,
          ),
          const SizedBox(height: 12),
          DailyTrendLineCard(
            title: strings.dailySpendingTrendTitle,
            points: AnalyticsService.computeDailyTrend(report.expenses),
            currencyCode: currency,
            strings: strings,
          ),
        ] else ...[
          // Who Pays Whom
        Text(
          strings.whoPaysWhom,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (report.transfers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppTheme.positiveGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(strings.allSettledMsg)),
                ],
              ),
            ),
          )
        else
          ...report.transfers.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
            final isExpanded = _expandedTransferIndices.contains(index);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: Tooltip(
                message:
                    '${t.fromMemberName} → ${t.toMemberName} (${AppFormatters.formatAmount(t.amount, currency)})',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTransferIndices.remove(index);
                      } else {
                        _expandedTransferIndices.add(index);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppTheme.negativeRed.withValues(alpha: 0.12),
                            foregroundColor: AppTheme.negativeRed,
                            radius: 18,
                            child: Text(
                              t.fromMemberName.isNotEmpty
                                  ? t.fromMemberName[0].toUpperCase()
                                  : '?',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: isExpanded
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.fromMemberName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons
                                                .subdirectory_arrow_right_rounded,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              t.toMemberName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          t.fromMemberName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          t.toMemberName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: t.isPaid
                                  ? AppTheme.positiveGreen
                                      .withValues(alpha: 0.14)
                                  : colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppFormatters.formatAmount(t.amount, currency),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: t.isPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: t.isPaid
                                    ? AppTheme.positiveGreen
                                    : colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          if (!widget.isOpenCycle &&
                              widget.onToggleTransferPaid != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: strings.markAsPaidHint,
                              onPressed: () =>
                                  widget.onToggleTransferPaid!(t.id, !t.isPaid),
                              icon: Icon(
                                t.isPaid
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: t.isPaid
                                    ? AppTheme.positiveGreen
                                    : colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // Member Breakdown
        Text(
          strings.memberBalances,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...report.balances.map((b) {
          final isPositive = b.netBalance > 0.005;
          final isNegative = b.netBalance < -0.005;
          final netColor = isPositive
              ? AppTheme.positiveGreen
              : (isNegative ? AppTheme.negativeRed : colorScheme.onSurfaceVariant);
          final statusText = isPositive
              ? strings.receivesLabel
              : (isNegative ? strings.owesLabel : strings.evenLabel);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  b.member.name.isNotEmpty
                      ? b.member.name[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(
                b.member.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                (b.advanceGiven > 0 || b.advanceReceived > 0)
                    ? '${strings.totalPaid}: ${AppFormatters.formatAmount(b.totalPaid, currency)}  •  '
                        '${strings.fairShare}: ${AppFormatters.formatAmount(b.totalShare, currency)}  •  '
                        '${strings.advanceNetLabel}: ${AppFormatters.formatSignedAmount(b.advanceNet, currency)}'
                    : '${strings.totalPaid}: ${AppFormatters.formatAmount(b.totalPaid, currency)}  •  '
                        '${strings.fairShare}: ${AppFormatters.formatAmount(b.totalShare, currency)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatSignedAmount(b.netBalance, currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: netColor),
                  ),
                ],
              ),
            ),
          );
        }),

        if (!widget.isOpenCycle && report.expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '${strings.navExpenses} (${report.expenses.length})',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...report.expenses.map((expense) {
            final memberById = {for (final m in widget.allMembers) m.id: m};
            final payerName =
                memberById[expense.paidByMemberId]?.name ?? 'Unknown';
            final isAdvance = expense.isAdvance;
            final receiverName = isAdvance && expense.splits.isNotEmpty
                ? (memberById[expense.splits.first.memberId]?.name ?? 'Unknown')
                : '';
            final splitCount = expense.splits.isNotEmpty
                ? expense.splits.length
                : widget.allMembers.length;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAdvance
                      ? colorScheme.secondaryContainer
                      : colorScheme.primaryContainer,
                  foregroundColor: isAdvance
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onPrimaryContainer,
                  child: Icon(
                    isAdvance
                        ? Icons.swap_horiz_rounded
                        : iconForExpenseCategory(expense.category),
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        expense.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isAdvance) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          strings.advanceLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  isAdvance
                      ? '$payerName → $receiverName  •  ${AppFormatters.formatShortDate(expense.expenseDate)}'
                      : '${strings.paidByLabel}: $payerName  •  '
                          '${strings.splitSummary(splitCount, report.balances.length)}  •  '
                          '${AppFormatters.formatShortDate(expense.expenseDate)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  AppFormatters.formatAmount(expense.amount, currency),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isAdvance ? colorScheme.primary : null,
                  ),
                ),
              ),
            );
          }),
        ],

        if (widget.isOpenCycle && report.expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.onCloseCycle,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.task_alt),
            label: Text(strings.closeCycleBtn),
          ),
        ],
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CloseCycleDialog extends StatefulWidget {
  final AppStrings strings;

  const _CloseCycleDialog({required this.strings});

  @override
  State<_CloseCycleDialog> createState() => _CloseCycleDialogState();
}

class _CloseCycleDialogState extends State<_CloseCycleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.closeCycleTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.closeCycleBody),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.cycleNameLabel,
                hintText: strings.cycleNameHint,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? strings.requiredField
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_titleController.text.trim());
            }
          },
          child: Text(strings.confirm),
        ),
      ],
    );
  }
}
