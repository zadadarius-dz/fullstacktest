import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_card.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');

  String? _selectedCategoryId;
  bool _isActive = true;
  int _stockQuantity = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _formError;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categoryProvider = context.read<CategoryProvider>();
      await categoryProvider.load(force: true);

      Product? product;
      if (_isEdit) {
        product = await context
            .read<ProductProvider>()
            .getProduct(widget.productId!);
      }

      if (!mounted) return;

      setState(() {
        if (product != null) {
          _skuController.text = product.sku;
          _nameController.text = product.name;
          _descriptionController.text = product.description ?? '';
          _priceController.text = product.price.toStringAsFixed(
            product.price == product.price.roundToDouble() ? 0 : 2,
          );
          _minStockController.text = product.minStock.toString();
          _selectedCategoryId = product.categoryId;
          _isActive = product.isActive;
          _stockQuantity = product.stockQuantity;
        } else if (categoryProvider.categories.isNotEmpty) {
          _selectedCategoryId = categoryProvider.categories.first.id;
        }

        _loading = false;
        _error = categoryProvider.error;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data produk.';
        _loading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kategori baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama kategori',
            hintText: 'Contoh: Minuman',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || !mounted) return;

    final provider = context.read<CategoryProvider>();
    final category = await provider.create(name);
    if (!mounted) return;

    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gagal membuat kategori.')),
      );
    } else {
      setState(() => _selectedCategoryId = category.id);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _formError = 'Pilih kategori terlebih dahulu.');
      return;
    }

    final payload = <String, dynamic>{
      'sku': _skuController.text.trim(),
      'name': _nameController.text.trim(),
      'categoryId': _selectedCategoryId,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'minStock': int.parse(_minStockController.text.trim()),
      if (_isEdit) 'isActive': _isActive,
    };

    setState(() => _saving = true);

    try {
      final provider = context.read<ProductProvider>();
      final product = _isEdit
          ? await provider.updateProduct(widget.productId!, payload)
          : await provider.createProduct(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Produk berhasil diperbarui. Stok tidak berubah.'
                : 'Produk berhasil dibuat dengan stok awal 0.',
          ),
        ),
      );
      Navigator.of(context).pop(product);
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
        _formError = 'Gagal menyimpan produk.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Produk' : 'Produk Baru'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Menyiapkan form produk...');
    }

    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: _load,
      );
    }

    final categories = context.watch<CategoryProvider>().categories;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_formError != null) ...[
            InlineMessage(message: _formError!),
            const SizedBox(height: 12),
          ],
          if (_isEdit) ...[
            InlineMessage(
              message:
                  'Stok saat ini: $_stockQuantity. Perubahan data produk tidak mengubah stok.',
              isError: false,
            ),
            const SizedBox(height: 12),
          ],
          if (categories.isEmpty) ...[
            InlineMessage(
              message:
                  'Belum ada kategori. Buat kategori terlebih dahulu sebelum menyimpan produk.',
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _skuController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    hintText: 'Contoh: KOPI-001',
                    counterText: '',
                  ),
                  validator: (value) {
                    final sku = (value ?? '').trim();
                    if (sku.isEmpty) return 'SKU wajib diisi.';
                    if (sku.length > 64) return 'SKU maksimal 64 karakter.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Nama produk',
                    hintText: 'Contoh: Kopi Arabica 250g',
                    counterText: '',
                  ),
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.length < 2) return 'Nama minimal 2 karakter.';
                    if (name.length > 160) return 'Nama maksimal 160 karakter.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                        validator: (value) =>
                            value == null ? 'Kategori wajib dipilih.' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _createCategory,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Tambah kategori',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Harga (Rp)',
                        ),
                        validator: (value) {
                          final price = double.tryParse((value ?? '').trim());
                          if (price == null || price < 0) {
                            return 'Harga harus 0 atau lebih.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok minimum',
                        ),
                        validator: (value) {
                          final minStock = int.tryParse((value ?? '').trim());
                          if (minStock == null || minStock < 0) {
                            return 'Minimal 0.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if ((value ?? '').length > 500) {
                      return 'Deskripsi maksimal 500 karakter.';
                    }
                    return null;
                  },
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    title: const Text(
                      'Produk aktif',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Produk nonaktif tidak muncul di daftar produk.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || categories.isEmpty ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEdit ? 'Simpan perubahan' : 'Buat produk'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stok awal produk selalu 0 dan hanya berubah melalui transaksi IN/OUT.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
