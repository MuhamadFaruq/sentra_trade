import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../core/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.attach_money, color: SentraTheme.long),
            title: const Text('Currency'),
            subtitle: Text('Current: ${settings.currency}'),
            onTap: () => _showCurrencyPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
            title: const Text('Starting Equity'),
            subtitle: Text('${settings.currency} ${settings.startingEquity}'),
            onTap: () {
              // Tambahkan logic input modal awal di sini
            },
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

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SentraTheme.surface,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: ['USD', 'IDR', 'EUR', 'GBP'].map((c) => ListTile(
            title: Text(c),
            onTap: () {
              ref.read(settingsProvider.notifier).updateCurrency(c);
              Navigator.pop(context);
            },
          )).toList(),
        );
      },
    );
  }
}