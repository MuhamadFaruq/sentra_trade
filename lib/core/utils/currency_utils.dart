import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/settings_provider.dart';

class DynamicCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String simplifiedText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    List<String> parts = simplifiedText.split(',');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;
    if (integerPart.isEmpty) integerPart = "0";
    final formatter = NumberFormat.decimalPattern('id');
    String formattedInteger = formatter.format(int.parse(integerPart));
    String finalString = formattedInteger;
    if (decimalPart != null) {
      finalString += ',${decimalPart.length > 5 ? decimalPart.substring(0, 5) : decimalPart}';
    }
    return newValue.copyWith(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}

extension CurrencyFormatter on double {
  // Fungsi 1: Untuk Saldo/Profit (dengan simbol Rp atau $)
  String toDynamicCurrency(WidgetRef ref) {
    final currency = ref.watch(settingsProvider).currency;
    
    // Tentukan simbol dan desimal secara spesifik untuk Rupiah
    String symbolToUse = '$currency ';
    int decimalDigits = 2;

    if (currency == 'IDR' || currency == 'Rp') {
      symbolToUse = 'Rp '; // Paksa jadi Rp meskipun di setting namanya IDR
      decimalDigits = 0;   // Hilangkan desimal (.29) untuk Rupiah
    }

    final formatter = NumberFormat.currency(
      symbol: symbolToUse,
      decimalDigits: decimalDigits,
      locale: 'id_ID', // Memastikan pemisah ribuan adalah titik
    );
    
    return formatter.format(this);
  }

  // Fungsi 2: Tetap sama, sudah benar untuk harga market
  String toPriceFormat() {
    if (this == floorToDouble()) {
      return NumberFormat.decimalPattern('id_ID').format(this);
    }
    return toStringAsFixed(2).replaceAll('.', ',');
  }
}