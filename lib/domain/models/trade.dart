import 'package:isar/isar.dart';

part 'trade.g.dart';

@collection
class Trade {
  Trade({
    this.id = Isar.autoIncrement,
    required this.pair,
    required this.direction,
    required this.orderFlowBias,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    this.exitPrice,
    this.profitLossAmount,
    this.isClosed = false,
    this.isWin,
    required this.entryDate,
    this.screenshotPath,
  });

  Id id;

  @Index()
  String pair;

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
  bool? isWin;

  DateTime entryDate;

  String? screenshotPath;
}

