import 'package:isar/isar.dart';

import '../models/trade.dart';

abstract class TradeRepository {
  Future<List<Trade>> getAllTrades();
  Future<Id> addTrade(Trade trade);
  Future<void> updateTrade(Trade trade);
  Future<bool> deleteTrade(Id id);
}

