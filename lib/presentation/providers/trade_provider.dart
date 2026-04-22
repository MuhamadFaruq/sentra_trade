import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/datasources/isar_datasource.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/models/trade.dart';
import '../../domain/repositories/trade_repository.dart';

/// Simple DI:
/// - Init Isar once via [IsarDatasource.init]
/// - Create repository implementation that can be overridden in tests.
final isarDatasourceProvider = FutureProvider<IsarDatasource>((ref) async {
  return IsarDatasource.init();
});

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final ds = ref.watch(isarDatasourceProvider).requireValue;
  return TradeRepositoryImpl(ds);
});

/// Provider untuk menampilkan semua daftar trade.
final tradeListProvider =
    AsyncNotifierProvider<TradeListNotifier, List<Trade>>(
  TradeListNotifier.new,
);

class TradeListNotifier extends AsyncNotifier<List<Trade>> {
  TradeRepository get _repo => ref.read(tradeRepositoryProvider);

  @override
  Future<List<Trade>> build() async {
    // Ensure Isar is initialized before the first fetch.
    await ref.watch(isarDatasourceProvider.future);
    return _repo.getAllTrades();
  }

  List<Trade> _currentListOrEmpty() => state.value ?? const <Trade>[];

  Future<Id> addTrade(Trade trade) async {
    final previous = _currentListOrEmpty();

    // Optimistic: tampilkan dulu (dengan id sementara) agar UI langsung update.
    final optimistic = Trade(
      id: trade.id,
      pair: trade.pair,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: trade.exitPrice,
      profitLossAmount: trade.profitLossAmount,
      isClosed: trade.isClosed,
      isWin: trade.isWin,
      entryDate: trade.entryDate,
      screenshotPath: trade.screenshotPath,
    );
    state = AsyncData([optimistic, ...previous]);

    try {
      final id = await _repo.addTrade(trade);

      // Sync: pastikan item yang baru punya id dari DB.
      final updated = _currentListOrEmpty().map((t) {
        if (identical(t, optimistic)) return t..id = id;
        return t;
      }).toList(growable: false);
      state = AsyncData(updated);
      return id;
    } catch (e, st) {
      // Rollback
      state = AsyncData(previous);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> toggleTradeStatus(Trade trade) async {
    final previous = _currentListOrEmpty();

    final toggled = Trade(
      id: trade.id,
      pair: trade.pair,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: trade.exitPrice,
      profitLossAmount: trade.profitLossAmount,
      isClosed: !trade.isClosed,
      isWin: trade.isWin,
      entryDate: trade.entryDate,
      screenshotPath: trade.screenshotPath,
    );

    // Optimistic update.
    state = AsyncData(
      previous.map((t) => t.id == trade.id ? toggled : t).toList(growable: false),
    );

    try {
      await _repo.updateTrade(toggled);
    } catch (e, st) {
      state = AsyncData(previous);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Close a trade with the given [exitPrice].
  /// Computes P/L and win/loss automatically based on direction.
  Future<void> closeTrade(Trade trade, double exitPrice) async {
    final previous = _currentListOrEmpty();

    final isLong = trade.direction.toLowerCase() == 'long';
    final pnl = isLong
        ? exitPrice - trade.entryPrice
        : trade.entryPrice - exitPrice;
    final win = pnl > 0;

    final closed = Trade(
      id: trade.id,
      pair: trade.pair,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: exitPrice,
      profitLossAmount: pnl,
      isClosed: true,
      isWin: win,
      entryDate: trade.entryDate,
      screenshotPath: trade.screenshotPath,
    );

    state = AsyncData(
      previous.map((t) => t.id == trade.id ? closed : t).toList(growable: false),
    );

    try {
      await _repo.updateTrade(closed);
    } catch (e, st) {
      state = AsyncData(previous);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// General-purpose update (e.g. attaching a screenshot).
  Future<void> updateTrade(Trade trade) async {
    final previous = _currentListOrEmpty();

    state = AsyncData(
      previous.map((t) => t.id == trade.id ? trade : t).toList(growable: false),
    );

    try {
      await _repo.updateTrade(trade);
    } catch (e, st) {
      state = AsyncData(previous);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> deleteTrade(Id id) async {
    final previous = _currentListOrEmpty();

    // Optimistic: hilangkan dari list.
    state = AsyncData(
      previous.where((t) => t.id != id).toList(growable: false),
    );

    try {
      final deleted = await _repo.deleteTrade(id);
      if (!deleted) {
        // rollback kalau ternyata tidak terhapus
        state = AsyncData(previous);
      }
      return deleted;
    } catch (e, st) {
      state = AsyncData(previous);
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

