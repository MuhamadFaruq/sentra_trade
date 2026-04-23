import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final String currency;
  final double startingEquity;

  SettingsState({required this.currency, required this.startingEquity});
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(currency: 'USD', startingEquity: 10000.0)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      currency: prefs.getString('currency') ?? 'USD',
      startingEquity: prefs.getDouble('startingEquity') ?? 10000.0,
    );
  }

  Future<void> updateCurrency(String newCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', newCurrency);
    state = SettingsState(currency: newCurrency, startingEquity: state.startingEquity);
  }
}