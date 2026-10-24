import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/movement_provider.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_card.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MovementProvider>().loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovementProvider>();
    final movements = provider.allMovements;

    if (provider.loading && movements.isEmpty) {
      return const LoadingView(message: 'Memuat riwayat stok...');
    }

    if (provider.error != null && movements.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: provider.loadAll,
      );
    }

    if (movements.isEmpty) {
      return const EmptyView(
        title: 'Belum ada riwayat',
        message:
            'Transaksi stok masuk dan keluar akan muncul di sini setelah dicatat dari detail produk.',
        icon: Icons.swap_vert_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: movements.length + 1,
        itemBuilder: (context, index) {
          if (index == movements.length) {
            if (provider.hasMoreAll) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: provider.loadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: provider.loadMoreAll,
                          child: const Text('Muat lebih banyak'),
                        ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '${formatNumber(provider.allTotalItems)} transaksi',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          final movement = movements[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: movement.isIn
                          ? AppColors.successSoft
                          : AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      movement.isIn
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: movement.isIn
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                movement.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TypeBadge(type: movement.type),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${movement.productSku} · ${movement.quantity} unit · '
                          '${movement.stockBefore} → ${movement.stockAfter}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatDateTime(movement.createdAt)}'
                          '${movement.note == null || movement.note!.isEmpty ? '' : ' · ${movement.note}'}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
