import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../providers/movement_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_card.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  Product? _product;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _formError;
  String _type = 'IN';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final product =
          await context.read<ProductProvider>().getProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
      });
      await context.read<MovementProvider>().loadForProduct(widget.productId);
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat detail produk.';
        _loading = false;
      });
    }
  }

  Future<void> _reloadProductOnly() async {
    try {
      final product =
          await context.read<ProductProvider>().getProduct(widget.productId);
      if (mounted) {
        setState(() => _product = product);
      }
    } catch (_) {
      // Riwayat sudah menampilkan error; detail lama tetap ditampilkan.
    }
  }

  Future<void> _submitMovement() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _formError = 'Quantity harus bilangan bulat positif.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final movement = await context.read<MovementProvider>().create(
            widget.productId,
            type: _type,
            quantity: quantity,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      await _reloadProductOnly();
      if (!mounted) return;

      _quantityController.clear();
      _noteController.clear();
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok ${movement.isIn ? 'masuk' : 'keluar'} ${movement.quantity} berhasil dicatat. '
            'Stok sekarang ${movement.stockAfter}.',
          ),
        ),
      );
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = exception.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = 'Gagal menyimpan transaksi stok.';
      });
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(productId: widget.productId),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _deleteProduct() async {
    final product = _product;
    if (product == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text(
          'Produk "${product.name}" akan dinonaktifkan. Riwayat stok tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<ProductProvider>().deleteProduct(widget.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil dihapus.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          product?.name ?? 'Detail Produk',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: product == null ? null : _openEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit produk',
          ),
          IconButton(
            onPressed: product == null ? null : _deleteProduct,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus produk',
          ),
        ],
      ),
      body: _buildBody(product),
    );
  }

  Widget _buildBody(Product? product) {
    if (_loading && product == null) {
      return const LoadingView(message: 'Memuat detail produk...');
    }

    if (_error != null && product == null) {
      return ErrorView(
        message: _error!,
        onRetry: _load,
      );
    }

    if (product == null) {
      return const EmptyView(
        title: 'Produk tidak ditemukan',
        message: 'Produk mungkin sudah dihapus atau bukan milik akun ini.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.sku,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StockBadge(
                      stock: product.stockQuantity,
                      minStock: product.minStock,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Kategori', value: product.categoryName),
                _InfoRow(
                  label: 'Harga',
                  value: formatCurrency(product.price),
                ),
                _InfoRow(
                  label: 'Stok saat ini',
                  value: formatNumber(product.stockQuantity),
                ),
                _InfoRow(
                  label: 'Stok minimum',
                  value: formatNumber(product.minStock),
                ),
                _InfoRow(
                  label: 'Status',
                  value: product.isActive ? 'Aktif' : 'Nonaktif',
                ),
                if (product.description != null &&
                    product.description!.isNotEmpty)
                  _InfoRow(
                    label: 'Deskripsi',
                    value: product.description!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catat pergerakan stok',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'IN menambah stok, OUT mengurangi. Stok tidak dapat menjadi negatif.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (_formError != null) ...[
                  InlineMessage(message: _formError!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Tipe'),
                        items: const [
                          DropdownMenuItem(value: 'IN', child: Text('IN — masuk')),
                          DropdownMenuItem(value: 'OUT', child: Text('OUT — keluar')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _type = value);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          hintText: '0',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Contoh: pembelian dari pemasok',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _submitMovement,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan transaksi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _HistorySection(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovementProvider>();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat stok produk',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat bersifat permanen dan tidak dapat diubah.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (provider.error != null) ...[
            InlineMessage(message: provider.error!),
            const SizedBox(height: 8),
          ],
          if (provider.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.productMovements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada transaksi untuk produk ini.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...provider.productMovements.map(
              (movement) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypeBadge(type: movement.type),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${movement.quantity} unit · ${movement.stockBefore} → ${movement.stockAfter}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDateTime(movement.createdAt)}${movement.note == null || movement.note!.isEmpty ? '' : ' · ${movement.note}'}',
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
            ),
          if (provider.hasMoreProduct)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed:
                    provider.loadingMore ? null : provider.loadMoreForProduct,
                child: provider.loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Muat riwayat lain'),
              ),
            ),
        ],
      ),
    );
  }
}
