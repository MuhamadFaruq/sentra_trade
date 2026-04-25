import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trade_provider.dart';
import '../../domain/models/trade.dart';
import '../widgets/trade_card.dart';
import '../../core/theme.dart';

class AllTradesHistoryScreen extends ConsumerStatefulWidget {
  const AllTradesHistoryScreen({super.key});

  @override
  ConsumerState<AllTradesHistoryScreen> createState() => _AllTradesHistoryScreenState();
}

class _AllTradesHistoryScreenState extends ConsumerState<AllTradesHistoryScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(tradeListProvider);
    final activeFilter = ref.watch(tradeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Trade History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // ── Fitur Pencarian ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search pair...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white38),
                    filled: true,
                    fillColor: SentraTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ── Fitur Filter Bar ──
              _buildFilterBar(ref, tradesAsync.value ?? []),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trades) {
          // Logika Filter + Pencarian
          final filtered = trades.where((t) {
            final matchesFilter = activeFilter == 'All' || t.pair == activeFilter;
            final matchesSearch = t.pair.toLowerCase().contains(searchQuery.toLowerCase());
            return matchesFilter && matchesSearch;
          }).toList()..sort((a, b) => b.entryDate.compareTo(a.entryDate));

          if (filtered.isEmpty) {
            return const Center(child: Text("No trades found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final trade = filtered[index];
              
              // ── Fitur Hapus (Swipe to Delete) ──
              return Dismissible(
                key: Key(trade.id.toString()),
                direction: DismissDirection.endToStart,
                
                // Background Merah saat digeser
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                ),

                // Konfirmasi Hapus
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Trade?'),
                      content: Text('Yakin ingin menghapus data ${trade.pair}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false), 
                          child: const Text('Batal')
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true), 
                          child: const Text('Hapus', style: TextStyle(color: Colors.red))
                        ),
                      ],
                    ),
                  );
                },

                // Aksi setelah diconfirm
                onDismissed: (direction) {
                  ref.read(tradeListProvider.notifier).deleteTrade(trade.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${trade.pair} berhasil dihapus')),
                  );
                },
                
                child: TradeCard(trade: trade),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, List<Trade> allTrades) {
    final pairs = ['All', ...allTrades.map((t) => t.pair).toSet()];
    final activeFilter = ref.watch(tradeFilterProvider);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pairs.length,
        itemBuilder: (context, index) {
          final pair = pairs[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(pair),
              selected: activeFilter == pair,
              onSelected: (_) => ref.read(tradeFilterProvider.notifier).state = pair,
              selectedColor: SentraTheme.long.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: activeFilter == pair ? SentraTheme.long : Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }
}