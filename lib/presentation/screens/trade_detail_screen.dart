import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';

class TradeDetailScreen extends ConsumerWidget {
  const TradeDetailScreen({super.key, required this.tradeId});

  final int tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradeListProvider);

    return tradesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (trades) {
        final trade = trades.where((t) => t.id == tradeId).firstOrNull;
        if (trade == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trade not found.')),
          );
        }
        return _DetailBody(trade: trade);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL BODY
// ─────────────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = trade.direction.toLowerCase() == 'long';
    final dirColor = isLong ? SentraTheme.long : SentraTheme.short;

    final risk = (trade.entryPrice - trade.stopLoss).abs();
    final reward = (trade.takeProfit - trade.entryPrice).abs();
    final rr = risk > 0 ? (reward / risk) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(trade.pair),
        actions: [
          if (!trade.isClosed)
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'Attach screenshot',
              onPressed: () => _pickScreenshot(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Status banner ──────────────────────────────────────────
          _StatusBanner(trade: trade, dirColor: dirColor, isLong: isLong),

          const SizedBox(height: 20),

          // ── Technical details ──────────────────────────────────────
          _SectionHeader(icon: Icons.candlestick_chart_outlined, label: 'Technical Details'),
          const SizedBox(height: 10),
          _DetailCard(
            children: [
              _DetailRow('Entry Price', trade.entryPrice.toStringAsFixed(5)),
              _DetailRow('Stop Loss', trade.stopLoss.toStringAsFixed(5),
                  color: SentraTheme.short),
              _DetailRow('Take Profit', trade.takeProfit.toStringAsFixed(5),
                  color: SentraTheme.long),
              _DetailRow('R:R Ratio', '1 : ${rr.toStringAsFixed(2)}',
                  color: rr >= 2
                      ? SentraTheme.long
                      : rr >= 1
                          ? Colors.amber
                          : SentraTheme.short),
              if (trade.isClosed && trade.exitPrice != null)
                _DetailRow('Exit Price', trade.exitPrice!.toStringAsFixed(5),
                    color: Colors.white),
              _DetailRow(
                'Entry Date',
                _formatDate(trade.entryDate),
              ),
            ],
          ),

          // ── P/L result (if closed) ─────────────────────────────────
          if (trade.isClosed && trade.profitLossAmount != null) ...[
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.assessment_outlined, label: 'Result'),
            const SizedBox(height: 10),
            _ResultCard(trade: trade),
          ],

          const SizedBox(height: 20),

          // ── Order Flow Bias ────────────────────────────────────────
          _SectionHeader(icon: Icons.psychology_outlined, label: 'Order Flow Bias'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SentraTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SentraTheme.outline),
            ),
            child: Text(
              trade.orderFlowBias.isNotEmpty
                  ? trade.orderFlowBias
                  : 'No analysis recorded.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: trade.orderFlowBias.isNotEmpty
                        ? Colors.white70
                        : Colors.white38,
                    height: 1.6,
                  ),
            ),
          ),

          // ── Close Trade button ─────────────────────────────────────
          if (!trade.isClosed) ...[
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _showCloseDialog(context, ref),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Close Trade'),
                style: FilledButton.styleFrom(
                  backgroundColor: SentraTheme.long,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          // ── Screenshot ─────────────────────────────────────────────
          if (trade.screenshotPath != null &&
              trade.screenshotPath!.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(icon: Icons.photo_outlined, label: 'Screenshot'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(trade.screenshotPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: SentraTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SentraTheme.outline),
                  ),
                  child: const Center(
                    child: Text('Image not found',
                        style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Close trade dialog ───────────────────────────────────────────────────
  void _showCloseDialog(BuildContext context, WidgetRef ref) {
    final exitCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SentraTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Close Trade',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the exit price to close ${trade.pair}.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: exitCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Exit Price',
                    prefixIcon: Icon(Icons.logout_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final exitPrice =
                          double.parse(exitCtrl.text.trim());
                      await ref
                          .read(tradeListProvider.notifier)
                          .closeTrade(trade, exitPrice);
                      if (ctx.mounted) Navigator.pop(ctx); // close sheet
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SentraTheme.long,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Confirm Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pick screenshot ──────────────────────────────────────────────────────
  Future<void> _pickScreenshot(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    final updated = Trade(
      id: trade.id,
      pair: trade.pair,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: trade.exitPrice,
      profitLossAmount: trade.profitLossAmount,
      isClosed: trade.isClosed,
      isWin: trade.isWin,
      entryDate: trade.entryDate,
      screenshotPath: image.path,
    );

    await ref.read(tradeListProvider.notifier).updateTrade(updated);
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

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.trade,
    required this.dirColor,
    required this.isLong,
  });
  final Trade trade;
  final Color dirColor;
  final bool isLong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            dirColor.withValues(alpha: 0.15),
            SentraTheme.surface,
          ],
        ),
        border: Border.all(color: dirColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isLong ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: dirColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isLong ? 'Long' : 'Short'} Position',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: dirColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  trade.pair,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trade.isClosed
                  ? Colors.white12
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: trade.isClosed
                    ? Colors.white24
                    : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              trade.isClosed ? 'Closed' : 'Open',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: trade.isClosed ? Colors.white70 : Colors.amber,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: SentraTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SentraTheme.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final pnl = trade.profitLossAmount ?? 0;
    final isWin = trade.isWin == true;
    final resultColor = isWin ? SentraTheme.long : SentraTheme.short;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isWin ? Icons.emoji_events_rounded : Icons.trending_down_rounded,
            color: resultColor,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWin ? 'Win' : 'Loss',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: resultColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trade closed at ${trade.exitPrice?.toStringAsFixed(5)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          Text(
            '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: resultColor,
                ),
          ),
        ],
      ),
    );
  }
}
