import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/trade.dart';


class ExportUtils {
  static Future<void> exportTradesToCSV(List<Trade> trades) async {
    // 1. Definisikan Header
    List<List<dynamic>> rows = [
      ["ID", "Pair", "Direction", "Entry Price", "SL", "TP", "Exit Price", "P/L", "Status", "Date", "Bias"]
    ];

    // 2. Masukkan Data
    for (var t in trades) {
      rows.add([
        t.id,
        t.pair,
        t.direction,
        t.entryPrice,
        t.stopLoss,
        t.takeProfit,
        t.exitPrice ?? 0,
        t.profitLossAmount ?? 0,
        t.isClosed ? (t.resultStatus ?? "CLOSED") : "OPEN",
        t.entryDate.toIso8601String(),
        t.orderFlowBias,
      ]);
    }

    // 3. Convert ke String CSV
    String csvData = const ListToCsvConverter().convert(rows);

    // 4. Simpan ke Temporary Directory
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/SentraTrade_Export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    // 5. Share File (Bisa dikirim via AirDrop ke Mac atau WhatsApp/Email ke Thinkpad)
    await Share.shareXFiles([XFile(path)], text: 'Ekspor Jurnal SentraTrade');
  }
}