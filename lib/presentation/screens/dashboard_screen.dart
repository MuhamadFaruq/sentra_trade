import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SentraTrade'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: navigate to "Add Trade" screen.
        },
        child: const Icon(Icons.add),
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load trades.\n$err',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        data: (trades) {
          final recent = [...trades]
            ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

          final closed = trades.where((t) => t.isClosed).toList();
          final totalProfit = closed.fold<double>(
            0,
            (sum, t) => sum + (t.profitLossAmount ?? 0),
          );
          final wins = closed.where((t) => t.isWin == true).length;
          final winRate = closed.isEmpty ? 0.0 : (wins / closed.length) * 100.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(
                totalProfit: totalProfit,
                winRate: winRate,
                closedCount: closed.length,
              ),
              const SizedBox(height: 16),
              Text(
                'Recent trades',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'No trades yet. Tap + to add your first one.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                )
              else
                ...recent.take(10).map((t) => _TradeTile(trade: t)),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalProfit,
    required this.winRate,
    required this.closedCount,
  });

  final double totalProfit;
  final double winRate;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    final profitColor = totalProfit >= 0 ? SentraTheme.long : SentraTheme.short;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Total Profit',
                    value: _formatPnL(totalProfit),
                    valueColor: profitColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    label: 'Win Rate',
                    value: '${winRate.toStringAsFixed(1)}%',
                    valueColor: Colors.white,
                    sublabel: '$closedCount closed',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPnL(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SentraTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SentraTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 6),
            Text(
              sublabel!,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}

class _TradeTile extends ConsumerWidget {
  const _TradeTile({required this.trade});

  final Trade trade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = trade.direction.toLowerCase() == 'long';
    final directionColor = isLong ? SentraTheme.long : SentraTheme.short;

    final subtitle = trade.isClosed
        ? 'Closed • P/L ${trade.profitLossAmount?.toStringAsFixed(2) ?? '—'}'
        : 'Open • Entry ${trade.entryPrice.toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                trade.pair,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: directionColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: directionColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                isLong ? 'Long' : 'Short',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: directionColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ),
        trailing: trade.isClosed
            ? null
            : IconButton(
                tooltip: 'Close trade',
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () async {
                  await ref.read(tradeProvider.notifier).closeTrade(trade);
                },
              ),
      ),
    );
  }
}

