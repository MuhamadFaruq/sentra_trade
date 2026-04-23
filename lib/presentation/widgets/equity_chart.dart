import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/trade_provider.dart';

class EquityChart extends ConsumerWidget {
  const EquityChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spots = ref.watch(equityChartProvider);

    if (spots.length < 2) {
      return const Center(child: Text("Not enough data for chart", style: TextStyle(color: Colors.white38)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false), // Sederhana dulu tanpa axis
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: SentraTheme.long,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: SentraTheme.long.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}