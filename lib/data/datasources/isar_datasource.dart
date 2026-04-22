import 'package:isar/isar.dart';

import '../../domain/models/trade.dart';

class IsarDatasource {
  IsarDatasource(this._isar);

  final Isar _isar;

  Future<List<Trade>> getAllTrades() {
    return _isar.trades.where().findAll();
  }

  Future<Id> addTrade(Trade trade) {
    return _isar.writeTxn(() async {
      return _isar.trades.put(trade);
    });
  }

  Future<void> updateTrade(Trade trade) async {
    await _isar.writeTxn(() async {
      await _isar.trades.put(trade);
    });
  }

  Future<bool> deleteTrade(Id id) {
    return _isar.writeTxn(() async {
      return _isar.trades.delete(id);
    });
  }
}

