import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';
import 'add_trade_screen.dart';
import 'trade_detail_screen.dart';

import '../../core/utils/chart_utils.dart';
import '../../core/utils/export_utils.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/currency_utils.dart';
import 'analytics_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Starting equity – replace with a real provider / persistent value if needed.
// ─────────────────────────────────────────────────────────────────────────────
const double _startingEquity = 10000.0;

// ... (Bagian import tetap sama)

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
            tooltip: 'Analytics',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Export CSV',
            onPressed: () {
              final trades = tradesAsync.value ?? [];
              if (trades.isNotEmpty) {
                ExportUtils.exportTradesToCSV(trades);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data')));
              }
            },
          ),
        ],
      ), // AKHIR APPBAR HARUS DI SINI
      
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

          // Logika statistik
          final closed = trades.where((t) => t.isClosed).toList();
          final totalPnL = closed.fold<double>(0, (sum, t) => sum + (t.profitLossAmount ?? 0));
          final equity = _startingEquity + totalPnL;
          final wins = closed.where((t) => t.resultStatus == 'Win').length;
          final winRate = closed.isEmpty ? 0.0 : (wins / closed.length) * 100.0;
          final filteredTrades = ref.watch(filteredTradesProvider);

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
              Text('Filter by Pair', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
              const SizedBox(height: 8),
              
              // MEMANGGIL FILTER BAR (Sekarang aman dipanggil di sini)
              _buildFilterBar(ref, trades), 

              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Recent Trades', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${filteredTrades.length} filtered', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 12),
              ...filteredTrades.take(20).map((t) => _TradeCard(trade: t)),
            ],
          );
        },
      ),
    );
  }

  // DEFINISIKAN FUNGSI DI SINI (Di luar build, di dalam class DashboardScreen)
  Widget _buildFilterBar(WidgetRef ref, List<Trade> allTrades) {
    // Tambahkan .toList() setelah toSet()
    final pairs = ['All', ...allTrades.map((t) => t.pair).toSet()];
    final activeFilter = ref.watch(tradeFilterProvider);

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pairs.length,
        itemBuilder: (context, index) {
          final pair = pairs[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(pair),
              selected: activeFilter == pair,
              onSelected: (_) => ref.read(tradeFilterProvider.notifier).state = pair,
              selectedColor: SentraTheme.long.withOpacity(0.2),
              labelStyle: TextStyle(
                color: activeFilter == pair ? SentraTheme.long : Colors.white54,
                fontWeight: activeFilter == pair ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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

Widget _buildEquityChart(List<Trade> trades) {
  final spots = ChartUtils.getEquitySpots(trades);

  return Container(
    height: 200,
    padding: const EdgeInsets.all(16),
    child: LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false), // Sembunyikan angka axis agar minimalis
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true, // Membuat garis melengkung agar halus
            color: const Color(0xFF00C087), // Warna hijau emerald khas SentraTrade
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00C087).withOpacity(0.1), // Efek bayangan di bawah garis
            ),
          ),
        ],
      ),
    ),
  );
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
  });

  final double equity;
  final double totalPnL;
  final double winRate;
  final int closedCount;
  final int totalCount;

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

  String _formatPnL(double value, WidgetRef ref) {
    final sign = value > 0 ? '+' : '';
    final currency = ref.watch(settingsProvider).currency;
    return '$sign$currency ${value.abs().toStringAsFixed(2)}';
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
                            '${pnlPositive ? '+' : ''}${pnl.toDynamicCurrency(ref)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pnlPositive ? SentraTheme.long : SentraTheme.short,
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
                            trade.resultStatus ?? 'Open',
                            style: TextStyle(
                              color: trade.resultStatus == 'Win' 
                                  ? SentraTheme.long 
                                  : trade.resultStatus == 'Loss' 
                                      ? SentraTheme.short 
                                      : Colors.amber, // Warna untuk BE atau Open
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
