import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models/trade.dart';
import '../providers/trade_provider.dart';
import '../providers/settings_provider.dart';
import '../../core/constants/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORMATTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Formatter dinamis: Mendukung titik ribuan dan koma desimal (Forex & Equity)
class DynamicCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Hanya izinkan angka dan satu koma untuk desimal
    String simplifiedText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    
    List<String> parts = simplifiedText.split(',');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    if (integerPart.isEmpty) integerPart = "0";
    
    // Format bagian bulat dengan titik sebagai ribuan (Locale Indonesia)
    final formatter = NumberFormat.decimalPattern('id');
    String formattedInteger = formatter.format(int.parse(integerPart));

    String finalString = formattedInteger;
    if (decimalPart != null) {
      // Limit desimal Forex biasanya maksimal 5 angka
      finalString += ',${decimalPart.length > 5 ? decimalPart.substring(0, 5) : decimalPart}';
    }

    return newValue.copyWith(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}

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
  final _marginCtrl = TextEditingController(); // Untuk Saldo/Margin
  final _feeCtrl = TextEditingController();    // Untuk Biaya Transaksi

  String _marketType = 'Forex';
  String? _selectedPair;
  bool _isLong = true;
  
  String _selectedStrategy = AppConstants.entryStrategies.first;
  final _entryPriceCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _biasCtrl = TextEditingController();
  final _leverageCtrl = TextEditingController(text: '1');

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

  /// Fungsi Helper untuk konversi teks berformat (1.000,50) ke Double (1000.50)
  double _parseInput(String value) {
    if (value.isEmpty) return 0.0;
    String cleanValue = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  void _setTargetByStrategy() {
    final entry = _parseInput(_entryPriceCtrl.text);
    final sl = _parseInput(_slCtrl.text);
    if (entry == 0 || sl == 0) return;

    final rule = AppConstants.strategyRules.firstWhere(
      (r) => r.name == _selectedStrategy,
      orElse: () => StrategyRule(name: 'Other', minRR: 1.0, description: ''),
    );
    final risk = (entry - sl).abs();
    
    double targetTP;
    if (_isLong) {
      targetTP = entry + (risk * rule.minRR);
    } else {
      targetTP = entry - (risk * rule.minRR);
    }

    setState(() {
      // Masukkan hasil hitung ke controller dengan format koma
      _tpCtrl.text = targetTP.toStringAsFixed(5).replaceAll('.', ',');
    });
  
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Target TP disesuaikan ke standar $_selectedStrategy (1:${rule.minRR})'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Di dalam class _AddTradeScreenState
  DateTime _entryDate = DateTime.now();
  DateTime? _exitDate; // Bisa null jika posisi masih running

  // Fungsi helper untuk memunculkan Picker
  Future<void> _pickDateTime(bool isEntry) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isEntry ? _entryDate : (_exitDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isEntry ? _entryDate : (_exitDate ?? DateTime.now())),
      );

      if (pickedTime != null) {
        setState(() {
          final finalDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
          if (isEntry) {
            _entryDate = finalDateTime;
          } else {
            _exitDate = finalDateTime;
          }
        });
      }
    }
  }

  // Taruh di bawah fungsi _setTargetByStrategy dan di atas fungsi build
  void _updateRRManual() {
    final entry = _parseInput(_entryPriceCtrl.text);
    final sl = _parseInput(_slCtrl.text);
    final tp = _parseInput(_tpCtrl.text);

    if (entry > 0 && sl > 0 && tp > 0) {
      double risk = _isLong ? (entry - sl) : (sl - entry);
      double reward = _isLong ? (tp - entry) : (entry - tp);
      
      if (risk > 0) {
        double rrRatio = reward / risk;
        // Kamu bisa simpan rrRatio ini ke sebuah variabel state jika ingin ditampilkan di tempat lain
        print("RR Ratio: 1:$rrRatio");
      }
    }
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final trade = Trade(
        pair: _selectedPair!,
        strategy: _selectedStrategy,
        direction: _isLong ? 'Long' : 'Short',
        orderFlowBias: _biasCtrl.text.trim(),
        entryPrice: _parseInput(_entryPriceCtrl.text),
        stopLoss: _parseInput(_slCtrl.text),
        takeProfit: _parseInput(_tpCtrl.text),
        marginUsed: _parseInput(_marginCtrl.text), // Simpan Margin
        transactionFee: _parseInput(_feeCtrl.text), // Simpan Fee
        leverage: int.tryParse(_leverageCtrl.text) ?? 1,
        entryDate: _entryDate,
        exitDate: _exitDate,
      );

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

  String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dirColor = _isLong ? SentraTheme.long : SentraTheme.short;
    final settings = ref.watch(settingsProvider);

    final pricingCurrency = settings.lockPricingToUsd ? 'USD' : settings.currency;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Trade')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const _SectionLabel('Market & Pair'),
              const SizedBox(height: 8),
              Row(
                children: [
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
              const SizedBox(height: 20),
              const _SectionLabel('Strategy'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue : _selectedStrategy,
                decoration: const InputDecoration(
                  labelText: 'Select Strategy',
                  prefixIcon: Icon(Icons.psychology_rounded),
                ),
                items: AppConstants.entryStrategies
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedStrategy = v);
                },
                dropdownColor: SentraTheme.surface,
              ),
              const SizedBox(height: 20),
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

              const _SectionLabel('Execution Time'),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Tombol Entry Date
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Entry Time',
                      dateTime: _entryDate,
                      icon: Icons.access_time_rounded,
                      onTap: () => _pickDateTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol Exit Date
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Exit Time',
                      dateTime: _exitDate,
                      icon: Icons.exit_to_app_rounded,
                      hint: 'Still Open',
                      onTap: () => _pickDateTime(false),
                    ),
                  ),
                ],
              ),

              // ── TRADE CAPITAL (Tetap mengikuti Settings, misal: IDR) ──
              const _SectionLabel('Trade Capital'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2, // Margin lebih lebar
                    child: _PriceField( 
                      label: 'Position Size',
                      icon: Icons.account_balance_wallet_outlined,
                      controller: _marginCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1, // Leverage lebih kecil
                    child: TextFormField(
                      controller: _leverageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Leverage',
                        suffixText: 'x',
                        prefixIcon: Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── PRICING (Dikunci ke USD) ──
              const _SectionLabel('Pricing (Market Price)'),
              _PriceField(
                controller: _entryPriceCtrl,
                label: 'Entry Price',
                icon: Icons.login_rounded,
                overrideCurrency: pricingCurrency,
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
                      overrideCurrency: pricingCurrency,
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
                      overrideCurrency: pricingCurrency,
                      validator: _requiredNumber,
                    ),
                  ),
                ],
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _setTargetByStrategy,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Auto TP by Strategy'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amber,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _RRRatioWidget(
                entryText: _entryPriceCtrl.text,
                slText: _slCtrl.text,
                tpText: _tpCtrl.text,
                strategyName: _selectedStrategy,
              ),

              const SizedBox(height: 28),
              const _SectionLabel('Order Flow Bias'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _biasCtrl,
                maxLines: 8,
                minLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Describe your analysis...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe your reasoning'
                    : null,
              ),

              const SizedBox(height: 36),
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
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Save Trade', style: TextStyle(fontWeight: FontWeight.w700)),
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
// UI HELPERS & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PriceField extends ConsumerWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.icon,
    this.iconColor,
    this.validator,
    this.overrideCurrency, // Tambahkan ini
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final String? Function(String?)? validator;
  final String? overrideCurrency; // Tambahkan ini

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gunakan overrideCurrency jika ada, jika tidak gunakan dari settings
    final activeCurrency = overrideCurrency ?? ref.watch(settingsProvider).currency;
    

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DynamicCurrencyFormatter()],
      decoration: InputDecoration(
        labelText: '$label ($activeCurrency)',
        prefixIcon: Icon(icon, color: iconColor ?? Colors.white54),
        suffixText: activeCurrency,
        suffixStyle: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
        hintText: '0,00',
      ),
      validator: validator,
    );
  }
}

class _RRRatioWidget extends StatelessWidget {
  const _RRRatioWidget({
    required this.entryText,
    required this.slText,
    required this.tpText,
    required this.strategyName,
  });

  final String entryText;
  final String slText;
  final String tpText;
  final String strategyName;

  double _parse(String val) => double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final entry = _parse(entryText);
    final sl = _parse(slText);
    final tp = _parse(tpText);

    if (entry == 0 || sl == 0 || tp == 0) {
      return _buildContainer(context, label: 'Risk / Reward', value: '—', sublabel: 'Fill pricing to calculate', color: Colors.white38);
    }

    final risk = (entry - sl).abs();
    final reward = (tp - entry).abs();
    if (risk == 0) return const SizedBox();

    final rr = reward / risk;
    final rule = AppConstants.strategyRules.firstWhere((r) => r.name == strategyName, orElse: () => StrategyRule(name: 'Other', minRR: 1.0, description: ''));
    final bool isSafe = rr >= rule.minRR;

    return _buildContainer(
      context,
      label: 'Strategy Validation: ${rule.name}',
      value: '1 : ${rr.toStringAsFixed(2)}',
      sublabel: isSafe ? '✅ Sesuai standar' : '⚠️ RR terlalu rendah!',
      color: isSafe ? SentraTheme.long : SentraTheme.short,
    );
  }

  Widget _buildContainer(BuildContext context, {required String label, required String value, required String sublabel, required Color color}) {
    return Container(
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16)),
            ]),
          ),
          Text(sublabel, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, letterSpacing: 0.4));
}

class _MarketChip extends StatelessWidget {
  const _MarketChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? SentraTheme.long.withValues(alpha: 0.15) : SentraTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? SentraTheme.long.withValues(alpha: 0.5) : SentraTheme.outline),
      ),
      child: Text(label, style: TextStyle(color: selected ? SentraTheme.long : Colors.white54, fontWeight: FontWeight.w600)),
    ),
  );
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});
  final String label; final IconData icon; final Color color; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: selected ? color.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: selected ? color : Colors.white38),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: selected ? color : Colors.white38, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.dateTime,
    required this.icon,
    required this.onTap,
    this.hint,
  });

  final String label;
  final DateTime? dateTime;
  final IconData icon;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SentraTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SentraTheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateTime != null 
                      ? DateFormat('dd/MM, HH:mm').format(dateTime!) 
                      : (hint ?? '-'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}