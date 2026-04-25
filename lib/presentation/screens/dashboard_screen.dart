import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';
import 'add_trade_screen.dart';
import 'trade_detail_screen.dart';
import 'all_trades_history_screen.dart';
import '../widgets/trade_card.dart';

import '../../core/utils/chart_utils.dart';
import '../../core/utils/export_utils.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/currency_utils.dart';
import 'analytics_screen.dart';

const double _startingEquity = 10000.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradeListProvider);
    final settings = ref.watch(settingsProvider);
    final startingEquity = settings.startingEquity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SentraTrade'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            onPressed: () {
              final trades = tradesAsync.value ?? [];
              if (trades.isNotEmpty) ExportUtils.exportTradesToCSV(trades);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTradeScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Trade'),
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => _ErrorView(error: err),
        data: (trades) {
          if (trades.isEmpty) return const _EmptyState();

          // LOGIKA DATA (Taruh di sini agar rapi)
          final closed = trades.where((t) => t.isClosed).toList();
          final totalPnL = closed.fold<double>(0, (sum, t) => sum + (t.profitLossAmount ?? 0));
          final equity = _startingEquity + totalPnL;
          final wins = closed.where((t) => t.resultStatus == 'Win').length;
          final winRate = closed.isEmpty ? 0.0 : (wins / closed.length) * 100.0;
          final pnlPercentage = startingEquity > 0 
            ? (totalPnL / startingEquity) * 100 
            : 0.0;

          // Ambil 10 trade terbaru secara keseluruhan (Clean - Tanpa Filter di Home)
          final recentTrades = trades.toList()
            ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _SummaryCard(
                equity: equity, 
                totalPnL: totalPnL, 
                winRate: winRate,
                closedCount: closed.length, 
                totalCount: trades.length,
                pnlPercentage: pnlPercentage,
              ),
              const SizedBox(height: 24),
              Text('Performance Analytics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: SentraTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SentraTheme.outline),
                ),
                child: _buildEquityChart(trades),
              ),
              const SizedBox(height: 24),
              
              // HEADER RECENT TRADES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Trades', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllTradesHistoryScreen())),
                    child: const Text('See All', style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // LIST 10 TERAKHIR (Tanpa gangguan filter)
              if (recentTrades.isEmpty)
                const Center(child: Text("No trades yet."))
              else
                ...recentTrades.take(10).map((t) => TradeCard(trade: t)),
            ],
          );
        },
      ),
    );
  }

  // --- HELPER WIDGETS ---
  // Fungsi _buildFilterBar dihapus dari sini karena sudah dipindah ke History

  Widget _buildEquityChart(List<Trade> trades) {
    final spots = ChartUtils.getEquitySpots(trades);
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF00C087),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF00C087).withOpacity(0.1)),
            ),
          ],
        ),
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

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.equity,
    required this.totalPnL,
    required this.winRate,
    required this.closedCount,
    required this.totalCount,
    required this.pnlPercentage,
  });

  final double equity;
  final double totalPnL;
  final double winRate;
  final int closedCount;
  final int totalCount;
  final double pnlPercentage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              equity.toDynamicCurrency(ref),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    fontSize: 16,
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
                    value: _formatPnL(totalPnL, ref),
                    valueColor: pnlColor,
                    sublabel: '${totalPnL >= 0 ? '▲' : '▼'} ${pnlPercentage.toStringAsFixed(2)}% from start',
                    icon: isProfit
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    iconColor: pnlColor,
                    percentage: pnlPercentage,
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

  String _formatPnL(double value, WidgetRef ref) {
    final sign = value > 0 ? '+' : '';
    final formatted = value.abs().toDynamicCurrency(ref);
    // return value >= 0 ? '+$formatted' : '-$formatted';
    // final currency = ref.watch(settingsProvider).currency;
    // return '$sign$currency ${value.abs().toStringAsFixed(2)}';
    final String formattedValue = value.toDynamicCurrency(ref);
    return value >= 0 ? '+$formattedValue' : formattedValue;
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
    this.percentage,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;
  final double? percentage;
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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8, // Jarak antara nominal dan persentase
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: valueColor, fontSize: 18),
            ),
            if (percentage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${percentage! >= 0 ? '+' : ''}${percentage!.toStringAsFixed(2)}%',
                  style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
