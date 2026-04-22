import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/trade.dart';

class IsarDatasource {
  IsarDatasource(this._isar);

  final Isar _isar;

  /// Inisialisasi Isar DB di path dokumen aplikasi.
  ///
  /// Panggil ini sekali dari composition root (misalnya saat app startup),
  /// lalu injeksikan instance datasource/repository ke Riverpod.
  static Future<IsarDatasource> init({String instanceName = 'sentra_trade'}) async {
    final existing = Isar.getInstance(instanceName);
    if (existing != null) return IsarDatasource(existing);

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [TradeSchema],
      directory: dir.path,
      name: instanceName,
    );
    return IsarDatasource(isar);
  }

  Isar get isar => _isar;

  /// GET: ambil semua trade.
  Future<List<Trade>> getAllTrades() => _isar.trades.where().findAll();

  /// GET: ambil trade berdasarkan id.
  Future<Trade?> getTradeById(Id id) => _isar.trades.get(id);

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

  Future<void> close() => _isar.close();
}

