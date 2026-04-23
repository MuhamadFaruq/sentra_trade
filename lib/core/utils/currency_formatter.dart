import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DynamicCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // 1. Hapus semua karakter kecuali angka dan koma (sebagai desimal)
    String simplifiedText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    
    // 2. Pisahkan bagian bulat dan desimal
    List<String> parts = simplifiedText.split(',');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    // 3. Format bagian bulat dengan titik sebagai ribuan
    if (integerPart.isEmpty) integerPart = "0";
    final formatter = NumberFormat.decimalPattern('id');
    String formattedInteger = formatter.format(int.parse(integerPart));

    // 4. Gabungkan kembali
    String finalString = formattedInteger;
    if (decimalPart != null) {
      // Batasi desimal Forex biasanya sampai 5 angka
      finalString += ',${decimalPart.length > 5 ? decimalPart.substring(0, 5) : decimalPart}';
    }

    return newValue.copyWith(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}