import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final String currency;
  final double startingEquity;
  final bool lockPricingToUsd;

  SettingsState({
    required this.currency, 
    required this.startingEquity,
    this.lockPricingToUsd = false,
  });
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(currency: 'USD', startingEquity: 0.0)) {
    _loadSettings();
  }
  final String _apiKey = "YOUR_API_KEY";

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedCurrency = prefs.getString('currency') ?? 'USD';
    final loadedEquity = prefs.getDouble('startingEquity') ?? 0.0;
    final loadedLock = prefs.getBool('lockPricingToUsd') ?? false;

    state = SettingsState(
      currency: loadedCurrency,
      startingEquity: loadedEquity,
      lockPricingToUsd: loadedLock,
    );
  }

  // UBAH: Dari updateStartingEquity menjadi depositEquity atau addEquity
  Future<void> depositEquity(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Logika penambahan: Saldo saat ini + nominal baru
    final newTotalEquity = state.startingEquity + amount;
    
    await prefs.setDouble('startingEquity', newTotalEquity);
    
    state = SettingsState(
      currency: state.currency,
      startingEquity: newTotalEquity,
      lockPricingToUsd: state.lockPricingToUsd,
    );
  }

  // Opsional: Fungsi untuk reset saldo jika ingin mulai dari nol lagi
  Future<void> resetEquity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('startingEquity', 0.0);
    state = SettingsState(
      currency: state.currency,
      startingEquity: 0.0,
      lockPricingToUsd: state.lockPricingToUsd,
    );
  }

  Future<void> updateCurrency(String newCurrency) async {
    final oldCurrency = state.currency;
    
    // Jika mata uang sama, tidak perlu konversi
    if (oldCurrency == newCurrency) return;

    try {
      // 1. Panggil API untuk mendapatkan kurs (pair conversion)
      final url = Uri.parse('https://v6.exchangerate-api.com/v6/$_apiKey/pair/$oldCurrency/$newCurrency');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double rate = data['conversion_rate'];

        // 2. Hitung Equity baru
        final double convertedEquity = state.startingEquity * rate;

        // 3. Simpan ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currency', newCurrency);
        await prefs.setDouble('startingEquity', convertedEquity);

        // 4. Update State
        state = SettingsState(
          currency: newCurrency,
          startingEquity: convertedEquity,
          lockPricingToUsd: state.lockPricingToUsd,
        );
        
        print("Berhasil konversi dari $oldCurrency ke $newCurrency dengan kurs $rate");
      }
    } catch (e) {
      // Jika error (misal internet mati), kita tetap ubah mata uangnya 
      // tapi ingatkan user bahwa saldo tidak terkonversi otomatis
      print("Gagal mengambil kurs: $e");
      _updateCurrencyOnly(newCurrency);
    }
  }

  // Fungsi cadangan jika API gagal
  Future<void> _updateCurrencyOnly(String newCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', newCurrency);
    state = SettingsState(
      currency: newCurrency,
      startingEquity: state.startingEquity,
      lockPricingToUsd: state.lockPricingToUsd,
    );
  }

  Future<void> toggleLockPricing(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lockPricingToUsd', value);
    state = SettingsState(
      currency: state.currency,
      startingEquity: state.startingEquity,
      lockPricingToUsd: value,
    );
  }
}