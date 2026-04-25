import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';
import '../screens/trade_detail_screen.dart';
import '../../core/utils/currency_utils.dart';

class TradeCard extends ConsumerWidget {
  const TradeCard({super.key, required this.trade});

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
              Container(width: 4, height: 72, color: dirColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  trade.pair,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                _DirectionBadge(isLong: isLong, color: dirColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(trade.entryDate),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      _TrailingInfo(
                        trade: trade,
                        hasPnL: hasPnL,
                        pnl: pnl,
                        pnlPositive: pnlPositive,
                        onClose: () => ref.read(tradeListProvider.notifier).toggleTradeStatus(trade),
                      ),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// Komponen kecil untuk merapikan kode
class _DirectionBadge extends StatelessWidget {
  final bool isLong;
  final Color color;
  const _DirectionBadge({required this.isLong, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isLong ? 'Long' : 'Short',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// Bagian Trailing Info yang diperhalus
class _TrailingInfo extends ConsumerWidget {
  final Trade trade;
  final bool hasPnL;
  final double pnl;
  final bool pnlPositive;
  final VoidCallback onClose;

  const _TrailingInfo({
    required this.trade, 
    required this.hasPnL, 
    required this.pnl, 
    required this.pnlPositive, 
    required this.onClose
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasPnL) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center, // Tambahan agar center secara vertikal
        children: [
          Text(
            '${pnlPositive ? '+' : ''}${pnl.toDynamicCurrency(ref)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, // Lebih tebal untuk angka profit
                  color: pnlPositive ? SentraTheme.long : SentraTheme.short,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            trade.resultStatus ?? 'Closed',
            style: TextStyle(
              fontSize: 11, // Sedikit lebih kecil agar kontras
              fontWeight: FontWeight.w600,
              color: trade.resultStatus == 'Win' 
                  ? SentraTheme.long 
                  : trade.resultStatus == 'Loss' 
                      ? SentraTheme.short 
                      : Colors.amber,
            ),
          ),
        ],
      );
    } else {
      // Tampilan tombol "Close" yang lebih clean
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Open', 
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(), // Menghilangkan padding default
            padding: const EdgeInsets.all(8),
            icon: Icon(Icons.check_circle_outline_rounded, 
                color: SentraTheme.long.withValues(alpha: 0.7), size: 22),
            onPressed: onClose,
          ),
        ],
      );
    }
  }
}