import 'package:isar/isar.dart';

import '../../domain/models/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/isar_datasource.dart';

class TradeRepositoryImpl implements TradeRepository {
  TradeRepositoryImpl(this._datasource);

  final IsarDatasource _datasource;

  @override
  Future<List<Trade>> getAllTrades() => _datasource.getAllTrades();

  @override
  Future<Id> addTrade(Trade trade) => _datasource.addTrade(trade);

  @override
  Future<void> updateTrade(Trade trade) => _datasource.updateTrade(trade);

  @override
  Future<bool> deleteTrade(Id id) => _datasource.deleteTrade(id);
}

