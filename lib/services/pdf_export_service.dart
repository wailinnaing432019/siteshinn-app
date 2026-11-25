import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/formatters.dart';
import '../data/models/account.dart';
import '../data/models/member.dart';
import '../data/models/settlement_summary.dart';

class PdfExportService {
  static Future<File> generateCyclePdf({
    required Account account,
    required CycleSettlementReport report,
    required List<Member> allMembers,
    required AppStrings strings,
  }) async {
    final regularFontData =
        await rootBundle.load('assets/fonts/Pyidaungsu-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/Pyidaungsu-Bold.ttf');

    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final pdf = pw.Document(theme: theme);
    final memberById = {for (final m in allMembers) m.id: m};
    final currency = account.currencyCode;

    final primaryColor = PdfColor.fromHex('#0F766E');
    final lightBg = PdfColor.fromHex('#F0FDFA');
    final borderColor = PdfColor.fromHex('#CBD5E1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'SiteShinn (စိုက်ရှင်း) • Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SiteShinn • ${account.name}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${strings.displayCycleTitle(report.cycle)}  |  ${AppFormatters.formatDateRange(report.cycle.startDate, report.cycle.endDate)}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      strings.totalSpent,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      AppFormatters.formatAmount(report.totalExpense, currency),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Who Pays Whom Section
          pw.Text(
            strings.whoPaysWhom,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          if (report.transfers.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(strings.allSettledMsg,
                  style: const pw.TextStyle(fontSize: 10)),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headers: ['From', 'To', 'Amount'],
              data: report.transfers
                  .map(
                    (t) => [
                      t.fromMemberName,
                      t.toMemberName,
                      AppFormatters.formatAmount(t.amount, currency),
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 18),

          // Member Balances Section
          pw.Text(
            strings.memberBalances,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headers: [
              'Member',
              strings.totalPaid,
              strings.fairShare,
              strings.netBalance,
            ],
            data: report.balances
                .map(
                  (b) => [
                    b.member.name,
                    AppFormatters.formatAmount(b.totalPaid, currency),
                    AppFormatters.formatAmount(b.totalShare, currency),
                    AppFormatters.formatSignedAmount(b.netBalance, currency),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),

          // Itemized Expenses Section
          pw.Text(
            '${strings.navExpenses} (${report.expenses.length})',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          if (report.expenses.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(2.4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.3),
              },
              headers: [
                strings.dateLabel,
                strings.titleLabel.split('(').first.trim(),
                strings.categoryLabel,
                strings.paidByLabel,
                strings.amountLabel,
              ],
              data: report.expenses.map((e) {
                final payerName =
                    memberById[e.paidByMemberId]?.name ?? 'Unknown';
                return [
                  AppFormatters.formatShortDate(e.expenseDate),
                  e.title,
                  strings.categoryName(e.category),
                  payerName,
                  AppFormatters.formatAmount(e.amount, currency),
                ];
              }).toList(),
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final cycleTitle = strings.displayCycleTitle(report.cycle);
    final safeName =
        '${account.name}_$cycleTitle'.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final file = File(p.join(dir.path, '${safeName}_report.pdf'));
    await file.writeAsBytes(await pdf.save());
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
}
