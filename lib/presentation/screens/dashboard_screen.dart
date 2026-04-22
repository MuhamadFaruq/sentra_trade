import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';
import 'add_trade_screen.dart';
import 'trade_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Starting equity – replace with a real provider / persistent value if needed.
// ─────────────────────────────────────────────────────────────────────────────
const double _startingEquity = 10000.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SentraTrade'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Statistics',
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTradeScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Trade'),
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => _ErrorView(error: err),
        data: (trades) {
          if (trades.isEmpty) return const _EmptyState();

          final recent = [...trades]
            ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

          final closed = trades.where((t) => t.isClosed).toList();
          final totalPnL = closed.fold<double>(
            0,
            (sum, t) => sum + (t.profitLossAmount ?? 0),
          );
          final equity = _startingEquity + totalPnL;
          final wins = closed.where((t) => t.isWin == true).length;
          final winRate =
              closed.isEmpty ? 0.0 : (wins / closed.length) * 100.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _SummaryCard(
                equity: equity,
                totalPnL: totalPnL,
                winRate: winRate,
                closedCount: closed.length,
                totalCount: trades.length,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Recent Trades',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${recent.length} total',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...recent.take(20).map((t) => _TradeCard(trade: t)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load trades.\n$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SentraTheme.long.withValues(alpha: 0.18),
                    SentraTheme.short.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: SentraTheme.outline,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.candlestick_chart_outlined,
                size: 46,
                color: SentraTheme.long.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Pusat Kendali Kosong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada trade di pusat kendali.\nMulai analisis sekarang!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white54, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTradeScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Trade Pertama'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CARD  (Equity · Win Rate · P/L Total)
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.equity,
    required this.totalPnL,
    required this.winRate,
    required this.closedCount,
    required this.totalCount,
  });

  final double equity;
  final double totalPnL;
  final double winRate;
  final int closedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final isProfit = totalPnL >= 0;
    final pnlColor = isProfit ? SentraTheme.long : SentraTheme.short;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151A22), // slightly lighter dark
            Color(0xFF0D1117), // deep dark
          ],
        ),
        border: Border.all(
          color: SentraTheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: pnlColor.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tag row ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pnlColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights_rounded,
                          size: 13, color: pnlColor),
                      const SizedBox(width: 5),
                      Text(
                        'Portfolio Summary',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: pnlColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalCount trades',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white30),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Equity (hero metric) ───────────────────────────────────
            Text(
              'Equity',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${equity.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
            ),

            const SizedBox(height: 20),

            // ── Divider ────────────────────────────────────────────────
            Container(
              height: 1,
              color: SentraTheme.outline.withValues(alpha: 0.5),
            ),

            const SizedBox(height: 16),

            // ── P/L Total + Win Rate row ───────────────────────────────
            Row(
              children: [
                // P/L Total
                Expanded(
                  child: _MetricTile(
                    label: 'Profit / Loss',
                    value: _formatPnL(totalPnL),
                    valueColor: pnlColor,
                    icon: isProfit
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    iconColor: pnlColor,
                  ),
                ),

                // Vertical divider
                Container(
                  width: 1,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: SentraTheme.outline.withValues(alpha: 0.4),
                ),

                // Win Rate
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Win Rate',
                          value: '${winRate.toStringAsFixed(1)}%',
                          valueColor: Colors.white,
                          sublabel: '$closedCount closed',
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Mini progress ring
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value: winRate / 100,
                          strokeWidth: 3.5,
                          backgroundColor:
                              SentraTheme.outline.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            winRate >= 50 ? SentraTheme.long : SentraTheme.short,
                          ),
                        ),
                      ),
                    ],
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
    return '$sign\$${value.toStringAsFixed(2)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC TILE  (used inside summary card)
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor.withValues(alpha: 0.7)),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: 3),
          Text(
            sublabel!,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white30),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TradeCard extends ConsumerWidget {
  const _TradeCard({required this.trade});

  final Trade trade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = trade.direction.toLowerCase() == 'long';
    final dirColor = isLong ? SentraTheme.long : SentraTheme.short;

    final hasPnL = trade.isClosed && trade.profitLossAmount != null;
    final pnl = trade.profitLossAmount ?? 0;
    final pnlPositive = pnl >= 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TradeDetailScreen(tradeId: trade.id),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SentraTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SentraTheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            // Left accent bar (Long = green, Short = red)
            Container(width: 4, height: 72, color: dirColor),

            // Content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    // Left: Pair + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trade.pair,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                              ),
                              const SizedBox(width: 10),
                              // Direction badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: dirColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: dirColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  isLong ? 'Long' : 'Short',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: dirColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(trade.entryDate),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    // Right: P/L or status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasPnL)
                          Text(
                            '${pnlPositive ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pnlPositive
                                      ? SentraTheme.long
                                      : SentraTheme.short,
                                ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              'Open',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        if (hasPnL) ...[
                          const SizedBox(height: 4),
                          Text(
                            trade.isWin == true ? 'Win' : 'Loss',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: trade.isWin == true
                                      ? SentraTheme.long.withValues(alpha: 0.7)
                                      : SentraTheme.short
                                          .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ],
                    ),

                    // Close-trade action for open trades
                    if (!trade.isClosed) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Close trade',
                        icon: Icon(Icons.check_circle_outline_rounded,
                            color: SentraTheme.long.withValues(alpha: 0.6)),
                        onPressed: () async {
                          await ref
                              .read(tradeListProvider.notifier)
                              .toggleTradeStatus(trade);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
