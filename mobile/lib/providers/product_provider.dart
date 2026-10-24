import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider(ApiClient client) : _service = ProductService(client);

  final ProductService _service;

  List<Product> _products = <Product>[];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  int _page = 1;
  int _totalPages = 0;
  int _totalItems = 0;

  String _search = '';
  String _categoryId = '';
  bool _lowStock = false;

  List<Product> get products => List.unmodifiable(_products);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get page => _page;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  String get search => _search;
  String get categoryId => _categoryId;
  bool get lowStock => _lowStock;
  bool get hasMore => _page < _totalPages;

  Future<void> setFilters({
    String? search,
    String? categoryId,
    bool? lowStock,
  }) async {
    _search = search ?? _search;
    _categoryId = categoryId ?? _categoryId;
    _lowStock = lowStock ?? _lowStock;
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.list(
        page: 1,
        search: _search,
        categoryId: _categoryId,
        lowStock: _lowStock,
      );
      _products = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
      _totalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat produk.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final result = await _service.list(
        page: _page + 1,
        search: _search,
        categoryId: _categoryId,
        lowStock: _lowStock,
      );
      _products = [..._products, ...result.items];
      _page = result.page;
      _totalPages = result.totalPages;
      _totalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat produk berikutnya.';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<Product> getProduct(String id) => _service.get(id);

  Future<Product> createProduct(Map<String, dynamic> payload) async {
    final product = await _service.create(payload);
    await load();
    return product;
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> payload) async {
    final product = await _service.update(id, payload);
    await load();
    return product;
  }

  Future<void> deleteProduct(String id) async {
    await _service.delete(id);
    await load();
  }
}
