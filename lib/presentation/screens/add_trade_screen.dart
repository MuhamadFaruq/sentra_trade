import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAIR OPTIONS
// ─────────────────────────────────────────────────────────────────────────────

const _forexPairs = [
  'EUR/USD', 'GBP/USD', 'USD/JPY', 'AUD/USD', 'USD/CAD',
  'USD/CHF', 'NZD/USD', 'EUR/GBP', 'EUR/JPY', 'GBP/JPY',
  'AUD/JPY', 'EUR/AUD', 'GBP/AUD', 'EUR/NZD', 'XAU/USD',
];

const _cryptoPairs = [
  'BTC/USD', 'ETH/USD', 'BNB/USD', 'SOL/USD', 'XRP/USD',
  'ADA/USD', 'DOGE/USD', 'AVAX/USD', 'DOT/USD', 'MATIC/USD',
];

// ─────────────────────────────────────────────────────────────────────────────
// ADD TRADE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddTradeScreen extends ConsumerStatefulWidget {
  const AddTradeScreen({super.key});

  @override
  ConsumerState<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends ConsumerState<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Form values ──────────────────────────────────────────────────────────
  String _marketType = 'Forex';
  String? _selectedPair;
  bool _isLong = true;

  final _entryPriceCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _biasCtrl = TextEditingController();

  bool _isSaving = false;

  List<String> get _currentPairs =>
      _marketType == 'Forex' ? _forexPairs : _cryptoPairs;

  @override
  void initState() {
    super.initState();
    _entryPriceCtrl.addListener(_onPriceChanged);
    _slCtrl.addListener(_onPriceChanged);
    _tpCtrl.addListener(_onPriceChanged);
  }

  void _onPriceChanged() => setState(() {});

  @override
  void dispose() {
    _entryPriceCtrl.removeListener(_onPriceChanged);
    _slCtrl.removeListener(_onPriceChanged);
    _tpCtrl.removeListener(_onPriceChanged);
    _entryPriceCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _biasCtrl.dispose();
    super.dispose();
  }

  // ── Save action ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final trade = Trade(
      pair: _selectedPair!,
      direction: _isLong ? 'Long' : 'Short',
      orderFlowBias: _biasCtrl.text.trim(),
      entryPrice: double.parse(_entryPriceCtrl.text.trim()),
      stopLoss: double.parse(_slCtrl.text.trim()),
      takeProfit: double.parse(_tpCtrl.text.trim()),
      entryDate: DateTime.now(),
    );

    try {
      await ref.read(tradeListProvider.notifier).addTrade(trade);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Validators ───────────────────────────────────────────────────────────
  String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dirColor = _isLong ? SentraTheme.long : SentraTheme.short;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Trade')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // ── Market type + Pair ─────────────────────────────────────
              const _SectionLabel('Market & Pair'),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Market toggle chips
                  _MarketChip(
                    label: 'Forex',
                    selected: _marketType == 'Forex',
                    onTap: () => setState(() {
                      _marketType = 'Forex';
                      _selectedPair = null;
                    }),
                  ),
                  const SizedBox(width: 10),
                  _MarketChip(
                    label: 'Crypto',
                    selected: _marketType == 'Crypto',
                    onTap: () => setState(() {
                      _marketType = 'Crypto';
                      _selectedPair = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPair,
                decoration: const InputDecoration(
                  labelText: 'Select Pair',
                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                ),
                items: _currentPairs
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPair = v),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select a pair' : null,
                dropdownColor: SentraTheme.surface,
              ),

              const SizedBox(height: 28),

              // ── Direction toggle ───────────────────────────────────────
              const _SectionLabel('Direction'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: SentraTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SentraTheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DirectionButton(
                        label: 'Long',
                        icon: Icons.trending_up_rounded,
                        color: SentraTheme.long,
                        selected: _isLong,
                        onTap: () => setState(() => _isLong = true),
                      ),
                    ),
                    Container(width: 1, height: 48, color: SentraTheme.outline),
                    Expanded(
                      child: _DirectionButton(
                        label: 'Short',
                        icon: Icons.trending_down_rounded,
                        color: SentraTheme.short,
                        selected: !_isLong,
                        onTap: () => setState(() => _isLong = false),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Price inputs ───────────────────────────────────────────
              const _SectionLabel('Pricing'),
              const SizedBox(height: 8),
              _PriceField(
                controller: _entryPriceCtrl,
                label: 'Entry Price',
                icon: Icons.login_rounded,
                validator: _requiredNumber,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PriceField(
                      controller: _slCtrl,
                      label: 'Stop Loss',
                      icon: Icons.shield_outlined,
                      iconColor: SentraTheme.short,
                      validator: _requiredNumber,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PriceField(
                      controller: _tpCtrl,
                      label: 'Take Profit',
                      icon: Icons.flag_outlined,
                      iconColor: SentraTheme.long,
                      validator: _requiredNumber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Auto RR Ratio ──────────────────────────────────────────
              _RRRatioWidget(
                entryText: _entryPriceCtrl.text,
                slText: _slCtrl.text,
                tpText: _tpCtrl.text,
              ),

              const SizedBox(height: 28),

              // ── Order Flow Bias ────────────────────────────────────────
              const _SectionLabel('Order Flow Bias'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _biasCtrl,
                maxLines: 8,
                minLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText:
                      'Describe your analysis, market structure, '
                      'order flow reasoning…',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe your reasoning'
                    : null,
              ),

              const SizedBox(height: 36),

              // ── Save button ────────────────────────────────────────────
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: dirColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isLong
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text('Save Trade'),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white54,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
    );
  }
}

class _MarketChip extends StatelessWidget {
  const _MarketChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? SentraTheme.long.withValues(alpha: 0.15)
              : SentraTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? SentraTheme.long.withValues(alpha: 0.5)
                : SentraTheme.outline,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? SentraTheme.long : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? color : Colors.white38),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected ? color : Colors.white38,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.icon,
    this.iconColor,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor),
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTO R:R RATIO WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _RRRatioWidget extends StatelessWidget {
  const _RRRatioWidget({
    required this.entryText,
    required this.slText,
    required this.tpText,
  });

  final String entryText;
  final String slText;
  final String tpText;

  @override
  Widget build(BuildContext context) {
    final entry = double.tryParse(entryText.trim());
    final sl = double.tryParse(slText.trim());
    final tp = double.tryParse(tpText.trim());

    // Need all three values to compute
    if (entry == null || sl == null || tp == null) {
      return _buildContainer(
        context,
        label: 'Risk / Reward',
        value: '—',
        sublabel: 'Fill Entry, SL & TP to calculate',
        color: Colors.white38,
      );
    }

    final risk = (entry - sl).abs();
    final reward = (tp - entry).abs();

    if (risk == 0) {
      return _buildContainer(
        context,
        label: 'Risk / Reward',
        value: '∞',
        sublabel: 'SL = Entry (no risk)',
        color: Colors.amber,
      );
    }

    final rr = reward / risk;
    final rrFormatted = rr.toStringAsFixed(2);

    // Color based on quality: green ≥ 2, amber 1–2, red < 1
    final Color rrColor;
    final String quality;
    if (rr >= 2) {
      rrColor = SentraTheme.long;
      quality = 'Great';
    } else if (rr >= 1) {
      rrColor = Colors.amber;
      quality = 'Fair';
    } else {
      rrColor = SentraTheme.short;
      quality = 'Poor';
    }

    return _buildContainer(
      context,
      label: 'Risk / Reward',
      value: '1 : $rrFormatted',
      sublabel: '$quality  •  Risk ${risk.toStringAsFixed(2)}  →  '
          'Reward ${reward.toStringAsFixed(2)}',
      color: rrColor,
    );
  }

  Widget _buildContainer(
    BuildContext context, {
    required String label,
    required String value,
    required String sublabel,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.balance_rounded, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          Text(
            sublabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

