import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trade_provider.dart';
import '../../core/theme.dart';
import '../../core/utils/currency_utils.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(tradeAnalyticsProvider);
    final stats = analytics['strategyStats'] as Map<String, Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(title: const Text('Strategy Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Card untuk Avg PnL (Expectancy)
          _buildExpectancyCard(analytics['avgPnL'] as double, ref),
          const SizedBox(height: 24),
          
          Text('Performance by Strategy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          
          // List Strategi
          ...stats.entries.map((entry) {
            final int total = entry.value['total'];
            // Tambahkan pengecekan agar tidak terjadi pembagian dengan nol
            final double winRate = total > 0 
                ? (entry.value['wins'] / total) * 100 
                : 0.0;

            return _StrategyStatCard(
              name: entry.key,
              winRate: winRate,
              totalTrades: total,
              pnl: entry.value['pnl'],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpectancyCard(double avgPnL, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SentraTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SentraTheme.outline),
      ),
      child: Column(
        children: [
          const Text('Average PnL (Expectancy)', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Text(
            '${avgPnL >= 0 ? '+' : ''}${avgPnL.toDynamicCurrency(ref)}', 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: avgPnL >= 0 ? SentraTheme.long : SentraTheme.short
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyStatCard extends ConsumerWidget {
  final String name;
  final double winRate;
  final int totalTrades;
  final double pnl;

  const _StrategyStatCard({
    required this.name, 
    required this.winRate, 
    required this.totalTrades, 
    required this.pnl
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: SentraTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${winRate.toStringAsFixed(1)}% WR', 
                  style: TextStyle(color: winRate >= 50 ? SentraTheme.long : SentraTheme.short)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: winRate / 100,
              backgroundColor: Colors.white10,
              color: winRate >= 50 ? SentraTheme.long : SentraTheme.short,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$totalTrades Trades', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                // GANTI BARIS INI:
                Text('PnL: ${pnl.toDynamicCurrency(ref)}', 
                  style: TextStyle(color: pnl >= 0 ? SentraTheme.long : SentraTheme.short, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}