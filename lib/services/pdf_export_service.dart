import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/formatters.dart';
import '../data/models/account.dart';
import '../data/models/member.dart';
import '../data/models/personal_summary.dart';
import '../data/models/settlement_summary.dart';
import 'export_file_opener.dart';

class PdfExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.siteshinn.site_shinn/device_settings',
  );
  static const HtmlEscape _htmlEscape = HtmlEscape();

  static Map<String, dynamic> buildCyclePdfPayload({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
    String outputPath = '',
  }) {
    final memberById = {for (final m in allMembers) m.id: m};
    final currency = account.currencyCode;
    final expenseTitleHeader = strings.titleLabel.split('(').first.trim();

    final transferRows = report.transfers
        .map(
          (t) => [
            t.fromMemberName,
            t.toMemberName,
            AppFormatters.formatAmount(t.amount, currency),
            t.isPaid ? strings.markPaidLabel : '-',
          ],
        )
        .toList();

    final balanceRows = report.balances
        .map(
          (b) => [
            b.member.name,
            AppFormatters.formatAmount(b.totalPaid, currency),
            AppFormatters.formatAmount(b.totalShare, currency),
            AppFormatters.formatSignedAmount(b.netBalance, currency),
          ],
        )
        .toList();

    final expenseRows = report.expenses.map((e) {
      final payerName = memberById[e.paidByMemberId]?.name ?? 'Unknown';
      return [
        AppFormatters.formatShortDate(e.expenseDate),
        e.title,
        strings.categoryName(e.category),
        payerName,
        AppFormatters.formatAmount(e.amount, currency),
      ];
    }).toList();

    return {
      'outputPath': outputPath,
      'brandTitle': 'SiteShinn • ${account.name}',
      'subtitle':
          '${strings.displayCycleTitle(report.cycle)}  |  ${AppFormatters.formatDateRange(report.cycle.startDate, report.cycle.endDate ?? DateTime.now())}',
      'summaryLabel': strings.totalSpent,
      'summaryValue': AppFormatters.formatAmount(report.totalExpense, currency),
      'footerText': 'SiteShinn (စိုက်ရှင်း)',
      'sections': [
        {
          'title': strings.whoPaysWhom,
          'emptyMessage': strings.allSettledMsg,
          'headers': ['From', 'To', strings.amountLabel, 'Status'],
          'alignments': ['left', 'left', 'right', 'center'],
          'weights': [2.2, 2.2, 1.5, 1.0],
          'rows': transferRows,
        },
        {
          'title': strings.memberBalances,
          'headers': [
            'Member',
            strings.totalPaid,
            strings.fairShare,
            strings.netBalance,
          ],
          'alignments': ['left', 'right', 'right', 'right'],
          'weights': [2.2, 1.5, 1.5, 1.5],
          'rows': balanceRows,
        },
        {
          'title': '${strings.navExpenses} (${report.expenses.length})',
          'headers': [
            strings.dateLabel,
            expenseTitleHeader,
            strings.categoryLabel,
            strings.paidByLabel,
            strings.amountLabel,
          ],
          'alignments': ['left', 'left', 'left', 'left', 'right'],
          'weights': [1.3, 2.3, 1.4, 1.4, 1.3],
          'rows': expenseRows,
        },
      ],
    };
  }

  static Map<String, dynamic> buildPersonalPdfPayload({
    required Account account,
    required PersonalLedgerSummary summary,
    required String periodLabel,
    required AppStrings strings,
    String outputPath = '',
  }) {
    final currency = account.currencyCode;
    final expenseTitleHeader = strings.titleLabel.split('(').first.trim();

    final txRows = summary.filteredTransactions.map((tx) {
      final typeStr = tx.isIncome ? strings.incomeLabel : strings.expenseLabel;
      final signedAmount = tx.isIncome ? tx.amount : -tx.amount;
      return [
        AppFormatters.formatShortDate(tx.expenseDate),
        tx.title,
        strings.categoryName(tx.category),
        typeStr,
        AppFormatters.formatSignedAmount(signedAmount, currency),
      ];
    }).toList();

    return {
      'outputPath': outputPath,
      'brandTitle': 'SiteShinn • ${account.name}',
      'subtitle': '${strings.personalSummaryTitle}  |  $periodLabel',
      'summaryLabel': strings.currentBalanceLabel,
      'summaryValue':
          AppFormatters.formatAmount(summary.currentBalance, currency),
      'footerText': 'SiteShinn (စိုက်ရှင်း)',
      'sections': [
        {
          'headers': [
            strings.openingBalanceLabel,
            strings.totalIncomeLabel,
            strings.totalExpenseLabel,
            strings.currentBalanceLabel,
          ],
          'alignments': ['right', 'right', 'right', 'right'],
          'weights': [1.0, 1.0, 1.0, 1.0],
          'rows': [
            [
              AppFormatters.formatAmount(summary.openingBalance, currency),
              AppFormatters.formatAmount(summary.periodIncome, currency),
              AppFormatters.formatAmount(summary.periodExpense, currency),
              AppFormatters.formatAmount(summary.currentBalance, currency),
            ],
          ],
        },
        {
          'title':
              '${strings.navLedger} (${summary.filteredTransactions.length})',
          'headers': [
            strings.dateLabel,
            expenseTitleHeader,
            strings.categoryLabel,
            'Type',
            strings.amountLabel,
          ],
          'alignments': ['left', 'left', 'left', 'left', 'right'],
          'weights': [1.3, 2.3, 1.4, 1.1, 1.4],
          'rows': txRows,
        },
      ],
    };
  }

  /// Kept for HTML sanity tests and potential web/desktop fallback.
  static String buildCycleHtml({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) {
    final payload = buildCyclePdfPayload(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
    );
    final sections = payload['sections'] as List<dynamic>;
    final transfersRows = (sections[0] as Map)['rows'] as List<dynamic>;
    final transfersHtml = transfersRows.isEmpty
        ? _htmlEscape.convert(strings.allSettledMsg)
        : transfersRows
            .map((r) => (r as List).map((c) => _htmlEscape.convert('$c')).join(' | '))
            .join('\n');
    return '<html lang="${strings.isBurmese ? 'my' : 'en'}">'
        '${_htmlEscape.convert(payload['brandTitle'] as String)}\n$transfersHtml</html>';
  }

  static Future<File> generateCyclePdf({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final dir = await getTemporaryDirectory();
    final cycleTitle = strings.displayCycleTitle(report.cycle);
    final safeName =
        '${account.name}_$cycleTitle'.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final file = File(p.join(dir.path, '${safeName}_report.pdf'));

    final payload = buildCyclePdfPayload(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
      outputPath: file.path,
    );
    await _channel
        .invokeMethod<bool>('generateReportPdf', payload)
        .timeout(const Duration(seconds: 20));
    return file;
  }

  static Future<void> shareCyclePdf({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final file = await generateCyclePdf(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject:
            'SiteShinn - ${account.name} (${strings.displayCycleTitle(report.cycle)})',
      ),
    );
  }

  static Future<SavedExportResult?> saveCyclePdfToDevice({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final file = await generateCyclePdf(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
    );
    final bytes = await file.readAsBytes();
    final fileName = p.basename(file.path);
    final savedUri = await FilePicker.saveFile(
      dialogTitle: strings.saveToDevice,
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    if (savedUri == null) return null;
    return SavedExportResult(
      uriOrPath: savedUri.toString(),
      localFallbackPath: file.path,
      mimeType: 'application/pdf',
      fileName: fileName,
    );
  }

  static Future<File> generatePersonalPdf({
    required Account account,
    required PersonalLedgerSummary summary,
    required String periodLabel,
    required AppStrings strings,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName =
        '${account.name}_$periodLabel'.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final file = File(p.join(dir.path, '${safeName}_wallet.pdf'));

    final payload = buildPersonalPdfPayload(
      account: account,
      summary: summary,
      periodLabel: periodLabel,
      strings: strings,
      outputPath: file.path,
    );
    await _channel
        .invokeMethod<bool>('generateReportPdf', payload)
        .timeout(const Duration(seconds: 20));
    return file;
  }

  static Future<void> sharePersonalPdf({
    required Account account,
    required PersonalLedgerSummary summary,
    required String periodLabel,
    required AppStrings strings,
  }) async {
    final file = await generatePersonalPdf(
      account: account,
      summary: summary,
      periodLabel: periodLabel,
      strings: strings,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'SiteShinn - ${account.name} ($periodLabel)',
      ),
    );
  }

  static Future<SavedExportResult?> savePersonalPdfToDevice({
    required Account account,
    required PersonalLedgerSummary summary,
    required String periodLabel,
    required AppStrings strings,
  }) async {
    final file = await generatePersonalPdf(
      account: account,
      summary: summary,
      periodLabel: periodLabel,
      strings: strings,
    );
    final bytes = await file.readAsBytes();
    final fileName = p.basename(file.path);
    final savedUri = await FilePicker.saveFile(
      dialogTitle: strings.saveToDevice,
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    if (savedUri == null) return null;
    return SavedExportResult(
      uriOrPath: savedUri.toString(),
      localFallbackPath: file.path,
      mimeType: 'application/pdf',
      fileName: fileName,
    );
  }
}
