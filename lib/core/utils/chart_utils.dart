import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/trade.dart';

class ChartUtils {
  static List<FlSpot> getEquitySpots(List<Trade> trades) {
    // Kita hanya mengambil trade yang sudah close
    final closedTrades = trades.where((t) => t.isClosed).toList();
    
    // Urutkan berdasarkan tanggal entry (ascending)
    closedTrades.sort((a, b) => a.entryDate.compareTo(b.entryDate));

    List<FlSpot> spots = [const FlSpot(0, 0)]; // Titik awal (X=0, Y=0)
    double runningEquity = 0;

    for (int i = 0; i < closedTrades.length; i++) {
      // Tambahkan profit/loss ke akumulasi saldo
      runningEquity += closedTrades[i].profitLossAmount ?? 0;
      
      // X = urutan trade, Y = total profit/loss saat itu
      spots.add(FlSpot((i + 1).toDouble(), runningEquity));
    }

    return spots;
  }
}