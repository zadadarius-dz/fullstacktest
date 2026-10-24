import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_card.dart';
import '../products/product_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardProvider>().load();
      }
    });
  }

  Future<void> _refresh() => context.read<DashboardProvider>().load();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final user = context.watch<AuthProvider>().user;
    final summary = provider.summary;

    if (provider.loading && summary == null) {
      return const LoadingView(message: 'Memuat ringkasan inventaris...');
    }

    if (provider.error != null && summary == null) {
      return ErrorView(
        message: provider.error!,
        onRetry: _refresh,
      );
    }

    if (summary == null) {
      return EmptyView(
        title: 'Belum ada data',
        message: 'Tambahkan produk untuk melihat ringkasan inventaris.',
        actionLabel: 'Muat ulang',
        onAction: _refresh,
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 700;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.error != null) ...[
            InlineMessage(message: provider.error!),
            const SizedBox(height: 12),
          ],
          Text(
            'Halo, ${user?.name ?? 'Pengguna'}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Berikut kondisi inventaris Anda saat ini.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 1.4 : 1.5,
            children: [
              _StatTile(
                label: 'Produk aktif',
                value: formatNumber(summary.activeProducts),
                icon: Icons.inventory_2_outlined,
              ),
              _StatTile(
                label: 'Kategori',
                value: formatNumber(summary.categories),
                icon: Icons.category_outlined,
              ),
              _StatTile(
                label: 'Total unit',
                value: formatNumber(summary.totalStockUnits),
                icon: Icons.warehouse_outlined,
                accent: true,
              ),
              _StatTile(
                label: 'Stok menipis',
                value: formatNumber(summary.lowStockProducts),
                icon: Icons.warning_amber_rounded,
                warning: summary.lowStockProducts > 0,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Perlu restock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '${summary.lowStockItems.length} produk',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Produk dengan stok sama atau di bawah batas minimum.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (summary.lowStockItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Semua stok aman. Tidak ada produk yang perlu direstock.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...summary.lowStockItems.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.warningSoft,
                        foregroundColor: AppColors.warning,
                        child: Text(
                          item.stockQuantity.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.sku} · minimum ${item.minStock}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProductDetailScreen(productId: item.id),
                          ),
                        );
                        if (context.mounted) {
                          await _refresh();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionCard(
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stok hanya berubah melalui transaksi IN/OUT. Edit produk tidak akan mengubah jumlah stok.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final background = accent
        ? AppColors.primary
        : warning
            ? AppColors.warningSoft
            : AppColors.surface;
    final foreground = accent
        ? Colors.white
        : warning
            ? AppColors.warning
            : AppColors.text;
    final muted = accent ? const Color(0xFFC8E8E3) : AppColors.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? Colors.transparent
              : warning
                  ? const Color(0xFFFEDF89)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent ? Colors.white : AppColors.primary, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: foreground,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
