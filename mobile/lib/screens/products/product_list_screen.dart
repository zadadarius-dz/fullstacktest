import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_card.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoryProvider>().load(force: true);
      context.read<ProductProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applySearch() async {
    FocusScope.of(context).unfocus();
    await context.read<ProductProvider>().setFilters(
          search: _searchController.text.trim(),
        );
  }

  Future<void> _openForm({String? productId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(productId: productId),
      ),
    );
    if (mounted) {
      await context.read<ProductProvider>().load();
    }
  }

  Future<void> _openDetail(String productId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: productId),
      ),
    );
    if (mounted) {
      await context.read<ProductProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final categories = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SectionCard(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau SKU...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _applySearch();
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Bersihkan pencarian',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('category-${products.categoryId}'),
                          initialValue: products.categoryId.isEmpty
                              ? null
                              : products.categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Semua kategori'),
                            ),
                            ...categories.categories.map(
                              (category) => DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            context
                                .read<ProductProvider>()
                                .setFilters(categoryId: value ?? '');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          const Text(
                            'Stok menipis',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          Switch(
                            value: products.lowStock,
                            onChanged: (value) {
                              context
                                  .read<ProductProvider>()
                                  .setFilters(lowStock: value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (products.error != null && products.products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InlineMessage(message: products.error!),
            ),
          Expanded(
            child: _buildBody(products),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ProductProvider provider) {
    if (provider.loading && provider.products.isEmpty) {
      return const LoadingView(message: 'Memuat produk...');
    }

    if (provider.error != null && provider.products.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: provider.load,
      );
    }

    if (provider.products.isEmpty) {
      return EmptyView(
        title: 'Belum ada produk',
        message: 'Tambahkan produk pertama Anda. Stok awal selalu 0.',
        actionLabel: 'Tambah produk',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: provider.products.length + 1,
        itemBuilder: (context, index) {
          if (index == provider.products.length) {
            if (provider.hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: provider.loadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: provider.loadMore,
                          child: const Text('Muat lebih banyak'),
                        ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '${formatNumber(provider.totalItems)} produk',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          final product = provider.products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${product.sku} · ${product.categoryName} · ${formatCurrency(product.price)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StockBadge(
                      stock: product.stockQuantity,
                      minStock: product.minStock,
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => _openDetail(product.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
