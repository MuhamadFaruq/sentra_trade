import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/settings_provider.dart';

extension CurrencyFormatter on double {
  // Fungsi untuk memformat angka dengan simbol mata uang dari provider
  String toDynamicCurrency(WidgetRef ref) {
    final currency = ref.watch(settingsProvider).currency;
    return '$currency ${toStringAsFixed(2)}';
  }
}