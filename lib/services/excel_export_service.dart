import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/formatters.dart';
import '../data/models/account.dart';
import '../data/models/member.dart';
import '../data/models/settlement_summary.dart';

class ExcelExportService {
  static const String _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<({String fileName, Uint8List bytes})> buildCycleExcelData({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final excel = Excel.createExcel();
    final memberById = {for (final m in allMembers) m.id: m};
    final currency = account.currencyCode;

    final summarySheet = excel['Summary & Settlement'];
    final expensesSheet = excel['Expenses'];

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // --- Sheet 1: Summary & Settlement ---
    summarySheet.appendRow([
      TextCellValue('SiteShinn (စိုက်ရှင်း) - Settlement Report'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Account'),
      TextCellValue(account.name),
      TextCellValue('Currency'),
      TextCellValue(currency),
    ]);
    final cycleTitle = strings.displayCycleTitle(report.cycle);
    summarySheet.appendRow([
      TextCellValue('Cycle'),
      TextCellValue(cycleTitle),
      TextCellValue('Period'),
      TextCellValue(
        AppFormatters.formatDateRange(
          report.cycle.startDate,
          report.cycle.endDate,
        ),
      ),
    ]);
    summarySheet.appendRow([
      TextCellValue(strings.totalSpent),
      DoubleCellValue(report.totalExpense),
    ]);
    summarySheet.appendRow([]);

    // Who Pays Whom
    summarySheet.appendRow([TextCellValue(strings.whoPaysWhom)]);
    summarySheet.appendRow([
      TextCellValue('From'),
      TextCellValue('To'),
      TextCellValue('Amount ($currency)'),
    ]);
    if (report.transfers.isEmpty) {
      summarySheet.appendRow([TextCellValue(strings.allSettledMsg)]);
    } else {
      for (final t in report.transfers) {
        summarySheet.appendRow([
          TextCellValue(t.fromMemberName),
          TextCellValue(t.toMemberName),
          DoubleCellValue(t.amount),
        ]);
      }
    }
    summarySheet.appendRow([]);

    // Member Breakdown
    summarySheet.appendRow([TextCellValue(strings.memberBalances)]);
    summarySheet.appendRow([
      TextCellValue('Member'),
      TextCellValue('${strings.totalPaid} ($currency)'),
      TextCellValue('${strings.fairShare} ($currency)'),
      TextCellValue('${strings.netBalance} ($currency)'),
    ]);
    for (final b in report.balances) {
      summarySheet.appendRow([
        TextCellValue(b.member.name),
        DoubleCellValue(b.totalPaid),
        DoubleCellValue(b.totalShare),
        DoubleCellValue(b.netBalance),
      ]);
    }

    // --- Sheet 2: Expenses ---
    expensesSheet.appendRow([
      TextCellValue(strings.dateLabel),
      TextCellValue(strings.titleLabel.split('(').first.trim()),
      TextCellValue(strings.categoryLabel),
      TextCellValue(strings.paidByLabel),
      TextCellValue('${strings.amountLabel} ($currency)'),
      TextCellValue(strings.splitAmongLabel),
    ]);

    for (final e in report.expenses) {
      final payer = memberById[e.paidByMemberId]?.name ?? 'Unknown';
      final splitNames = e.splits
          .map((s) => memberById[s.memberId]?.name ?? 'Unknown')
          .join(', ');
      expensesSheet.appendRow([
        TextCellValue(AppFormatters.formatDate(e.expenseDate)),
        TextCellValue(e.title),
        TextCellValue(strings.categoryName(e.category)),
        TextCellValue(payer),
        DoubleCellValue(e.amount),
        TextCellValue(splitNames),
      ]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Failed to encode Excel file.');
    }

    final safeName =
        '${account.name}_$cycleTitle'.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return (
      fileName: '${safeName}_report.xlsx',
      bytes: Uint8List.fromList(encoded),
    );
  }

  static Future<File> generateCycleExcel({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final data = await buildCycleExcelData(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
    );
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, data.fileName));
    await file.writeAsBytes(data.bytes, flush: true);
    return file;
  }

  static Future<void> shareCycleExcel({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final file = await generateCycleExcel(
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

  static Future<bool> saveCycleExcelToDevice({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final data = await buildCycleExcelData(
      account: account,
      report: report,
      allMembers: allMembers,
      strings: strings,
    );
    final savedUri = await FilePicker.saveFile(
      dialogTitle: strings.saveToDevice,
      fileName: data.fileName,
      bytes: data.bytes,
      mimeType: _xlsxMimeType,
    );
    return savedUri != null;
  }
}
