import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahkan ini untuk FilteringTextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../core/theme.dart';
import '../../core/utils/currency_utils.dart'; // Import ini agar bisa pakai toDynamicCurrency

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── KELOMPOK MATA UANG ──
          ListTile(
            leading: const Icon(Icons.attach_money, color: SentraTheme.long),
            title: const Text('Primary Currency'),
            subtitle: Text('Digunakan untuk Margin & Fee: ${settings.currency}'),
            onTap: () => _showCurrencyPicker(context, ref),
          ),

          SwitchListTile(
            title: const Text('Lock Pricing to USD'),
            subtitle: const Text('Selalu gunakan USD untuk harga Entry/SL/TP'),
            secondary: const Icon(Icons.lock_outline_rounded, color: Colors.amber),
            value: settings.lockPricingToUsd,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleLockPricing(value);
            },
            activeThumbColor: const Color(0xFF00C087), 
          ),

          const Divider(color: SentraTheme.outline),

          // ── KELOMPOK MODAL ──
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
            title: const Text('Starting Equity'),
            // Gunakan format yang sudah kita buat agar rapi (Rp 10.000.000)
            subtitle: Text(settings.startingEquity.toDynamicCurrency(ref)),
            onTap: () => _showEquityDialog(context, ref, settings.startingEquity),
          ),
          
          const Divider(color: SentraTheme.outline),

          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.white54),
            title: Text('App Version'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.white30)),
          ),
        ],
      ),
    );
  }

  // DIALOG INPUT UNTUK MODAL AWAL
  void _showEquityDialog(BuildContext context, WidgetRef ref, double currentEquity) {
    // Gunakan formatter agar user gampang ngetik angka jutaan
    final controller = TextEditingController(text: currentEquity.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SentraTheme.surface,
        title: const Text('Update Starting Equity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Initial Capital',
            hintText: 'e.g. 10000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text) ?? 0.0;
              ref.read(settingsProvider.notifier).updateStartingEquity(newValue);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SentraTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['USD', 'IDR', 'EUR', 'GBP'].map((c) => ListTile(
              title: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: ref.read(settingsProvider).currency == c 
                  ? const Icon(Icons.check_circle, color: SentraTheme.long) 
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).updateCurrency(c);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        );
      },
    );
  }
}