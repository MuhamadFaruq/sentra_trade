import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../domain/models/trade.dart';
import '../../domain/repositories/trade_repository.dart';

/// Provide an implementation of [TradeRepository] from your composition root.
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  throw UnimplementedError('Provide a TradeRepository implementation');
});

final tradeProvider = AsyncNotifierProvider<TradeNotifier, List<Trade>>(
  TradeNotifier.new,
);

class TradeNotifier extends AsyncNotifier<List<Trade>> {
  TradeRepository get _repo => ref.read(tradeRepositoryProvider);

  @override
  Future<List<Trade>> build() async {
    return _repo.getAllTrades();
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getAllTrades);
  }

  Future<Id> addTrade(Trade trade) async {
    final id = await _repo.addTrade(trade);
    await _reload();
    return id;
  }

  Future<void> updateTrade(Trade trade) async {
    await _repo.updateTrade(trade);
    await _reload();
  }

  Future<void> closeTrade(
    Trade trade, {
    double? exitPrice,
    double? profitLossAmount,
    bool? isWin,
  }) async {
    trade
      ..isClosed = true
      ..exitPrice = exitPrice ?? trade.exitPrice
      ..profitLossAmount = profitLossAmount ?? trade.profitLossAmount
      ..isWin = isWin ?? trade.isWin;

    await _repo.updateTrade(trade);
    await _reload();
  }

  Future<bool> deleteTrade(Id id) async {
    final deleted = await _repo.deleteTrade(id);
    await _reload();
    return deleted;
  }
}

