import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/settlement_cycle.dart';
import '../../data/models/settlement_summary.dart';
import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../widgets/account_charts.dart';
import 'settlement_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final cycles = dashboard?.settledCycles ?? [];

    if (cycles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                strings.noHistoryYet,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final activeAccount = dashboard?.activeAccount;
    final currencyCode = activeAccount?.currencyCode ?? 'MMK';
    final cycleKey = cycles.map((c) => c.id).join(',');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cycles.isNotEmpty)
          FutureBuilder<List<CycleTrendPoint>>(
            key: ValueKey(cycleKey),
            future:
                ref.read(dashboardProvider.notifier).loadSettledCycleTrends(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              return CycleTrendChartCard(
                points: snapshot.data!,
                currencyCode: currencyCode,
                strings: strings,
              );
            },
          ),
        ...cycles.map((cycle) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.verified_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                strings.displayCycleTitle(cycle),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                AppFormatters.formatDateRange(cycle.startDate, cycle.endDate),
              ),
              trailing: Chip(
                label: Text(
                  strings.settledBadge,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CycleDetailScreen(cycle: cycle),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class CycleDetailScreen extends ConsumerStatefulWidget {
  final SettlementCycle cycle;

  const CycleDetailScreen({super.key, required this.cycle});

  @override
  ConsumerState<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends ConsumerState<CycleDetailScreen> {
  Future<CycleSettlementReport>? _reportFuture;

  void _refreshReport() {
    setState(() {
      _reportFuture = ref
          .read(dashboardProvider.notifier)
          .loadHistoricalReport(widget.cycle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final account = dashboard?.activeAccount;

    if (account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _reportFuture ??=
        ref.read(dashboardProvider.notifier).loadHistoricalReport(widget.cycle);

    return Scaffold(
      appBar: AppBar(title: Text(strings.displayCycleTitle(widget.cycle))),
      body: FutureBuilder<CycleSettlementReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return CycleReportView(
            account: account,
            report: snapshot.data!,
            allMembers: dashboard?.members ?? [],
            strings: strings,
            isOpenCycle: false,
            onToggleTransferPaid: (transferId, isPaid) async {
              await ref
                  .read(dashboardProvider.notifier)
                  .markTransferPaid(transferId, isPaid);
              if (mounted) {
                _refreshReport();
              }
            },
          );
        },
      ),
    );
  }
}
