import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final String currency;
  final double startingEquity;
  final bool lockPricingToUsd; // Tambahkan variabel baru

  SettingsState({
    required this.currency, 
    required this.startingEquity,
    this.lockPricingToUsd = false, // Default false
  });
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(currency: 'USD', startingEquity: 10000.0)) {
    _loadSettings();
  }

  // 1. FUNGSI UNTUK MEMBACA (LOAD) DATA SAAT APP DIBUKA
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Kita baca dari disk, kalau kosong pakai default
    final loadedCurrency = prefs.getString('currency') ?? 'USD';
    final loadedEquity = prefs.getDouble('startingEquity') ?? 10000.0;
    final loadedLock = prefs.getBool('lockPricingToUsd') ?? false;

    state = SettingsState(
      currency: loadedCurrency,
      startingEquity: loadedEquity,
      lockPricingToUsd: loadedLock,
    );
  }

  Future<void> updateStartingEquity(double newEquity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('startingEquity', newEquity); // Simpan angka baru
    
    state = SettingsState(
      currency: state.currency,
      startingEquity: newEquity, // Update state dengan angka baru
      lockPricingToUsd: state.lockPricingToUsd,
    );
  }

  Future<void> updateCurrency(String newCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', newCurrency);
    state = SettingsState(
      currency: newCurrency, 
      startingEquity: state.startingEquity,
      lockPricingToUsd: state.lockPricingToUsd,
    );
  }

  // Fungsi baru untuk toggle Lock Pricing
  Future<void> toggleLockPricing(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lockPricingToUsd', value); // Simpan ke disk
    state = SettingsState(
      currency: state.currency,
      startingEquity: state.startingEquity,
      lockPricingToUsd: value,
    );
  }
}