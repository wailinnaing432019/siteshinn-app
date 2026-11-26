import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_icon.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/expense.dart';
import '../../data/models/personal_summary.dart';
import '../../providers/app_providers.dart';
import '../../services/excel_export_service.dart';
import '../../services/pdf_export_service.dart';
import '../widgets/export_sheet.dart';
import 'add_expense_screen.dart';

Future<void> showEditOpeningBalanceDialog(
  BuildContext context,
  WidgetRef ref,
  AppStrings strings,
  Account account,
) async {
  final initialText =
      account.openingBalance == account.openingBalance.roundToDouble()
          ? account.openingBalance.toInt().toString()
          : account.openingBalance.toString();
  final controller = TextEditingController(text: initialText);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(strings.editOpeningBalance),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: strings.openingBalanceLabel,
          suffixText: AppFormatters.symbolForCurrency(account.currencyCode),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(strings.save),
        ),
      ],
    ),
  );

  if (saved == true) {
    final parsed = double.tryParse(controller.text.replaceAll(',', '').trim());
    if (parsed != null && parsed >= 0) {
      await ref
          .read(dashboardProvider.notifier)
          .updateAccount(account.copyWith(openingBalance: parsed));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.invalidOpeningBalance)),
      );
    }
  }
  controller.dispose();
}

String _formatPeriodLabel(DateTimeRange? range, AppStrings strings) {
  if (range == null) return strings.allMonths;
  return '${AppFormatters.formatDate(range.start)} – ${AppFormatters.formatDate(range.end)}';
}

class _DateRangeFilterBar extends ConsumerWidget {
  const _DateRangeFilterBar();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isCurrentMonth(DateTimeRange? range) {
    if (range == null) return false;
    final current = PersonalDateRangeNotifier.currentMonthRange();
    return _isSameDay(range.start, current.start) &&
        _isSameDay(range.end, current.end);
  }

  Future<void> _pickStartDate(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange? current,
  ) async {
    final initial = current?.start ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final end = current?.end ?? picked;
    ref.read(personalDateRangeProvider.notifier).setRange(
          DateTimeRange(
            start: picked,
            end: end.isBefore(picked) ? picked : end,
          ),
        );
  }

  Future<void> _pickEndDate(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange? current,
  ) async {
    final initial = current?.end ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final start = current?.start ?? picked;
    ref.read(personalDateRangeProvider.notifier).setRange(
          DateTimeRange(
            start: start.isAfter(picked) ? picked : start,
            end: picked,
          ),
        );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange? current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          current ?? PersonalDateRangeNotifier.currentMonthRange(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(personalDateRangeProvider.notifier).setRange(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final range = ref.watch(personalDateRangeProvider);
    final isCurrentMonth = _isCurrentMonth(range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickStartDate(context, ref, range),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  range != null
                      ? AppFormatters.formatDate(range.start)
                      : strings.startDateLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward_rounded, size: 16),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickEndDate(context, ref, range),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: Text(
                  range != null
                      ? AppFormatters.formatDate(range.end)
                      : strings.endDateLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: strings.pickDateRange,
              onPressed: () => _pickRange(context, ref, range),
              icon: const Icon(Icons.date_range_outlined),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(strings.thisMonth, style: const TextStyle(fontSize: 12)),
                  selected: isCurrentMonth,
                  onSelected: (_) =>
                      ref.read(personalDateRangeProvider.notifier).setThisMonth(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(strings.last7Days, style: const TextStyle(fontSize: 12)),
                  onPressed: () =>
                      ref.read(personalDateRangeProvider.notifier).setLast7Days(),
                ),
              ),
              ChoiceChip(
                label: Text(strings.allMonths, style: const TextStyle(fontSize: 12)),
                selected: range == null,
                onSelected: (_) =>
                    ref.read(personalDateRangeProvider.notifier).setAllTime(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PersonalLedgerTab extends ConsumerStatefulWidget {
  const PersonalLedgerTab({super.key});

  @override
  ConsumerState<PersonalLedgerTab> createState() => _PersonalLedgerTabState();
}

class _PersonalLedgerTabState extends ConsumerState<PersonalLedgerTab> {
  String _searchQuery = '';
  TransactionType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final range = ref.watch(personalDateRangeProvider);
    final account = dashboard?.activeAccount;
    if (dashboard == null || account == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currency = account.currencyCode;
    final colorScheme = Theme.of(context).colorScheme;

    final summary = PersonalLedgerSummary.compute(
      account: account,
      allTransactions: dashboard.expenses,
      startDate: range?.start,
      endDate: range?.end,
      typeFilter: _typeFilter,
      searchQuery: _searchQuery,
    );

    return Column(
      children: [
        // Top Wallet Balance Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.currentBalanceLabel,
                      style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    InkWell(
                      onTap: () => showEditOpeningBalanceDialog(
                        context,
                        ref,
                        strings,
                        account,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${strings.openingBalanceLabel.split('(').first.trim()}: ${AppFormatters.formatAmount(summary.openingBalance, currency)}',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: colorScheme.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppFormatters.formatAmount(summary.currentBalance, currency),
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WalletMiniTile(
                        label: strings.totalIncomeLabel,
                        value:
                            '+${AppFormatters.formatAmount(summary.periodIncome, currency)}',
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    Expanded(
                      child: _WalletMiniTile(
                        label: strings.totalExpenseLabel,
                        value:
                            '-${AppFormatters.formatAmount(summary.periodExpense, currency)}',
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Date Range & Search Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: const _DateRangeFilterBar(),
        ),
        if (dashboard.expenses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: strings.personalSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(strings.all),
                    selected: _typeFilter == null,
                    onSelected: (_) => setState(() => _typeFilter = null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(strings.incomeLabel),
                    selected: _typeFilter == TransactionType.income,
                    onSelected: (sel) => setState(
                      () => _typeFilter = sel ? TransactionType.income : null,
                    ),
                  ),
                ),
                FilterChip(
                  label: Text(strings.expenseLabel),
                  selected: _typeFilter == TransactionType.expense,
                  onSelected: (sel) => setState(
                    () => _typeFilter = sel ? TransactionType.expense : null,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Transaction List
        Expanded(
          child: summary.filteredTransactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.noPersonalTxYet,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
                  itemCount: summary.filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = summary.filteredTransactions[index];
                    final isIncome = tx.isIncome;
                    final amountColor = isIncome
                        ? AppTheme.positiveGreen
                        : AppTheme.negativeRed;
                    final signed = isIncome ? tx.amount : -tx.amount;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: amountColor.withValues(alpha: 0.12),
                          foregroundColor: amountColor,
                          child: Icon(
                            iconForExpenseCategory(tx.category),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${strings.categoryName(tx.category)}  •  ${AppFormatters.formatShortDate(tx.expenseDate)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.formatSignedAmount(
                                signed,
                                currency,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: amountColor,
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddExpenseScreen(
                                        existingExpense: tx,
                                      ),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(strings.deleteExpenseTitle),
                                      content:
                                          Text(strings.deleteExpenseConfirm),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: Text(strings.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: Text(strings.delete),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref
                                        .read(dashboardProvider.notifier)
                                        .deleteExpense(tx.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(strings.edit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(strings.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddExpenseScreen(existingExpense: tx),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PersonalSummaryTab extends ConsumerStatefulWidget {
  const PersonalSummaryTab({super.key});

  @override
  ConsumerState<PersonalSummaryTab> createState() => _PersonalSummaryTabState();
}

class _PersonalSummaryTabState extends ConsumerState<PersonalSummaryTab> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final range = ref.watch(personalDateRangeProvider);
    final account = dashboard?.activeAccount;
    if (dashboard == null || account == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currency = account.currencyCode;
    final summary = PersonalLedgerSummary.compute(
      account: account,
      allTransactions: dashboard.expenses,
      startDate: range?.start,
      endDate: range?.end,
    );
    final periodLabel = _formatPeriodLabel(range, strings);

    final expenseByCategory = <ExpenseCategory, double>{};
    for (final tx in summary.filteredTransactions) {
      if (tx.isExpense) {
        expenseByCategory[tx.category] =
            (expenseByCategory[tx.category] ?? 0) + tx.amount;
      }
    }
    final sortedCategories = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const _DateRangeFilterBar(),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(
                  label: strings.openingBalanceLabel,
                  value: AppFormatters.formatAmount(
                    summary.openingBalance,
                    currency,
                  ),
                ),
                const Divider(),
                _SummaryRow(
                  label: strings.totalIncomeLabel,
                  value:
                      '+${AppFormatters.formatAmount(summary.periodIncome, currency)}',
                  valueColor: AppTheme.positiveGreen,
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: strings.totalExpenseLabel,
                  value:
                      '-${AppFormatters.formatAmount(summary.periodExpense, currency)}',
                  valueColor: AppTheme.negativeRed,
                ),
                const Divider(),
                _SummaryRow(
                  label: strings.currentBalanceLabel,
                  value: AppFormatters.formatAmount(
                    summary.currentBalance,
                    currency,
                  ),
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Export Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () async {
                        setState(() => _isExporting = true);
                        try {
                          await showExportOptionsSheet(
                            context: context,
                            strings: strings,
                            title: strings.exportPdf,
                            onShare: () => PdfExportService.sharePersonalPdf(
                              account: account,
                              summary: summary,
                              periodLabel: periodLabel,
                              strings: strings,
                            ),
                            onSaveToDevice: () =>
                                PdfExportService.savePersonalPdfToDevice(
                              account: account,
                              summary: summary,
                              periodLabel: periodLabel,
                              strings: strings,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isExporting = false);
                        }
                      },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label:
                    Text(_isExporting ? strings.exporting : strings.exportPdf),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () async {
                        setState(() => _isExporting = true);
                        try {
                          await showExportOptionsSheet(
                            context: context,
                            strings: strings,
                            title: strings.exportExcel,
                            onShare: () => ExcelExportService.sharePersonalExcel(
                              account: account,
                              summary: summary,
                              periodLabel: periodLabel,
                              strings: strings,
                            ),
                            onSaveToDevice: () =>
                                ExcelExportService.savePersonalExcelToDevice(
                              account: account,
                              summary: summary,
                              periodLabel: periodLabel,
                              strings: strings,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isExporting = false);
                        }
                      },
                icon: const Icon(Icons.table_chart_outlined),
                label: Text(
                    _isExporting ? strings.exporting : strings.exportExcel),
              ),
            ),
          ],
        ),

        if (sortedCategories.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            strings.categoryBreakdown,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...sortedCategories.map((entry) {
            final ratio = summary.periodExpense > 0
                ? (entry.value / summary.periodExpense).clamp(0.0, 1.0)
                : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(iconForExpenseCategory(entry.key), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.categoryName(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          AppFormatters.formatAmount(entry.value, currency),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: ratio,
                      borderRadius: BorderRadius.circular(4),
                    ),
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

class _WalletMiniTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WalletMiniTile({
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
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 16 : 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
