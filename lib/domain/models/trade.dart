import 'package:isar/isar.dart';

part 'trade.g.dart';

@collection
class Trade {
  Trade({
    this.id = Isar.autoIncrement,
    required this.pair,
    this.strategy = 'Other', // Perbaikan: Gunakan required this, bukan late String
    required this.direction,
    required this.orderFlowBias,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    this.exitPrice,
    this.profitLossAmount,
    this.isClosed = false,
    this.resultStatus,
    required this.entryDate,
    this.screenshotPath,
  });

  Id id;

  @Index()
  String pair;

  String strategy = 'Other'; // Definisikan variabelnya di sini

  /// "Long" or "Short"
  String direction;

  /// Detailed analysis / rationale
  String orderFlowBias;

  double entryPrice;
  double stopLoss;
  double takeProfit;

  double? exitPrice;
  double? profitLossAmount;

  bool isClosed;
  String? resultStatus;

  DateTime entryDate;

  String? screenshotPath;
}