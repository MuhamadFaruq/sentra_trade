import 'package:isar/isar.dart';

part 'trade.g.dart';

@collection
class Trade {
  Trade({
    this.id = Isar.autoIncrement,
    required this.pair,
    this.strategy = 'Other',
    required this.direction,
    required this.orderFlowBias,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    this.marginUsed = 0.0, 
    this.transactionFee = 0.0,
    this.leverage = 1, // Default 1x (Spot)
    this.exitPrice,
    this.profitLossAmount,
    this.isClosed = false,
    this.resultStatus,
    required this.entryDate,
    this.exitDate,
    this.screenshotPath,
  });

  Id id;

  @Index()
  String pair;
  String strategy; 

  String direction;
  String orderFlowBias;

  double entryPrice;
  double stopLoss;
  double takeProfit;

  double marginUsed;
  double transactionFee;

  // --- Tambahan Field Leverage ---
  /// Pengali modal (misal: 10, 20, 50)
  int leverage; 

  double? exitPrice;
  double? profitLossAmount;
  bool isClosed;
  
  String? resultStatus;
  
  DateTime entryDate;
  DateTime? exitDate;

  String? screenshotPath;

  // --- Logika Helper untuk Mahasiswa Informatika ---

  /// Menghitung total nilai posisi (Margin x Leverage)
  /// Contoh: Margin $100 x 10x = $1.000 Position Size
  double get positionSize => marginUsed * leverage;

  /// Menghitung profit bersih setelah dikurangi biaya transaksi
  double get netProfit => (profitLossAmount ?? 0.0) - transactionFee;
}