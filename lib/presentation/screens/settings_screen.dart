import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahkan ini untuk FilteringTextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../core/theme.dart';
import '../../core/utils/currency_utils.dart'; // Import ini agar bisa pakai toDynamicCurrency
import 'package:intl/intl.dart'; // Tambahkan ini

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
            title: const Text('Equity Management'),
            // Gunakan format yang sudah kita buat agar rapi (Rp 10.000.000)
            subtitle: Text(settings.startingEquity.toDynamicCurrency(ref)),
            onTap: () => _showEquityDialog(context, ref),
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

  // DIALOG INPUT UNTUK DEPOSIT/TAMBAH MODAL
  void _showEquityDialog(BuildContext context, WidgetRef ref) {
    // Biarkan kosong agar user langsung mengetik nominal tambahan
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SentraTheme.surface,
        title: const Text('Deposit Equity'), // Ubah judul
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // Tetap gunakan ini agar hanya angka yang masuk ke sistem
            CurrencyInputFormatter(), // Formatter kustom untuk tampilan titik
          ],
          decoration: const InputDecoration(
            labelText: 'Deposit Amount',
            hintText: 'e.g. 500.000',
            prefixText: 'IDR ', // Opsional: Tambahkan prefix agar user tahu mata uangnya
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () {
              // PENTING: Hapus titik sebelum melakukan parsing ke double
              final cleanValue = controller.text.replaceAll('.', '');
              final amountToAdd = double.tryParse(cleanValue) ?? 0.0;
              
              if (amountToAdd > 0) {
                ref.read(settingsProvider.notifier).depositEquity(amountToAdd);
              }
              Navigator.pop(context);
            },
            child: const Text('Add Balance'),
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
              onTap: () async {
                // 1. Jalankan proses update (yang sekarang sudah include API konversi)
                await ref.read(settingsProvider.notifier).updateCurrency(c);
                // 2. Tutup modal setelah proses selesai
                if (context.mounted) Navigator.pop(context);
              },
            )).toList(),
          ),
        );
      },
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (newValue.selection.baseOffset == 0) return newValue;

    // Menghapus semua karakter non-digit
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    double value = double.tryParse(cleanText) ?? 0;

    // Format menggunakan locale Indonesia untuk mendapatkan titik (.) sebagai pemisah
    final formatter = NumberFormat.decimalPattern('id');
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}