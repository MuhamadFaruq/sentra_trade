import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/datasources/isar_datasource.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/models/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import 'package:fl_chart/fl_chart.dart';

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
// ... provider lainnya di atas

final tradeFilterProvider = StateProvider<String>((ref) => 'All');

// --- PINDAHKAN INI KELUAR DARI filteredTradesProvider ---
final tradeAnalyticsProvider = Provider((ref) {
  final tradesAsync = ref.watch(tradeListProvider);
  final trades = tradesAsync.value ?? [];
  final closedTrades = trades.where((t) => t.isClosed).toList();

  double totalPnL = closedTrades.fold(0.0, (sum, t) => sum + (t.profitLossAmount ?? 0));
  double avgPnL = closedTrades.isEmpty ? 0.0 : totalPnL / closedTrades.length;

  Map<String, Map<String, dynamic>> strategyStats = {};

  for (var trade in closedTrades) {
    final strategy = trade.strategy;
    if (!strategyStats.containsKey(strategy)) {
      strategyStats[strategy] = {'wins': 0, 'total': 0, 'pnl': 0.0};
    }
    
    strategyStats[strategy]!['total']++;
    strategyStats[strategy]!['pnl'] += (trade.profitLossAmount ?? 0.0);
    if (trade.resultStatus == 'Win') {
      strategyStats[strategy]!['wins']++;
    }
  }

  return {
    'avgPnL': avgPnL,
    'strategyStats': strategyStats,
  };
});

// Provider Filtered Trades tetap berdiri sendiri
final filteredTradesProvider = Provider<List<Trade>>((ref) {
  final allTradesAsync = ref.watch(tradeListProvider);
  final filter = ref.watch(tradeFilterProvider);

  return allTradesAsync.maybeWhen(
    data: (trades) {
      if (filter == 'All') return trades;
      return trades.where((t) => t.pair == filter).toList();
    },
    orElse: () => [],
  );
});

final equityChartProvider = Provider<List<FlSpot>>((ref) {
  final tradesAsync = ref.watch(tradeListProvider);
  final trades = tradesAsync.value ?? [];
  
  final closedTrades = trades.where((t) => t.isClosed).toList()
    ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

  List<FlSpot> spots = [];
  double currentEquity = 0;
  
  spots.add(const FlSpot(0, 0));

  for (int i = 0; i < closedTrades.length; i++) {
    currentEquity += (closedTrades[i].profitLossAmount ?? 0);
    spots.add(FlSpot((i + 1).toDouble(), currentEquity));
  }

  return spots;
});

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
      strategy: trade.strategy,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: trade.exitPrice,
      profitLossAmount: trade.profitLossAmount,
      isClosed: trade.isClosed,
      resultStatus: trade.resultStatus,
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
      strategy: trade.strategy,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: trade.exitPrice,
      profitLossAmount: trade.profitLossAmount,
      isClosed: !trade.isClosed,
      resultStatus: !trade.isClosed ? null : trade.resultStatus,
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

    // Logika penentuan status (Win, Loss, atau BE)
    String status;
    if (pnl == 0) {
      status = 'BE';
    } else if (pnl > 0) {
      status = 'Win';
    } else {
      status = 'Loss';
    }

    final closed = Trade(
      id: trade.id,
      pair: trade.pair,
      strategy: trade.strategy,
      direction: trade.direction,
      orderFlowBias: trade.orderFlowBias,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
      exitPrice: exitPrice,
      profitLossAmount: pnl,
      isClosed: true,
      resultStatus: status,
      entryDate: trade.entryDate,
      screenshotPath: trade.screenshotPath,
    );

    state = AsyncData(
      previous.map((t) => t.id == trade.id ? closed : t).toList(),
    );

    await _repo.updateTrade(closed);
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

