import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/stock_movement.dart';
import '../services/movement_service.dart';

class MovementProvider extends ChangeNotifier {
  MovementProvider(ApiClient client) : _service = MovementService(client);

  final MovementService _service;

  List<StockMovement> _productMovements = <StockMovement>[];
  List<StockMovement> _allMovements = <StockMovement>[];

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  int _productPage = 1;
  int _productTotalPages = 0;
  int _productTotalItems = 0;
  String? _currentProductId;

  int _allPage = 1;
  int _allTotalPages = 0;
  int _allTotalItems = 0;

  List<StockMovement> get productMovements => List.unmodifiable(_productMovements);
  List<StockMovement> get allMovements => List.unmodifiable(_allMovements);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get productTotalItems => _productTotalItems;
  int get allTotalItems => _allTotalItems;
  bool get hasMoreProduct => _productPage < _productTotalPages;
  bool get hasMoreAll => _allPage < _allTotalPages;

  Future<void> loadForProduct(String productId) async {
    _currentProductId = productId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.listForProduct(productId, page: 1);
      _productMovements = result.items;
      _productPage = result.page;
      _productTotalPages = result.totalPages;
      _productTotalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat riwayat stok.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreForProduct() async {
    final productId = _currentProductId;
    if (productId == null || _loading || _loadingMore || !hasMoreProduct) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final result = await _service.listForProduct(
        productId,
        page: _productPage + 1,
      );
      _productMovements = [..._productMovements, ...result.items];
      _productPage = result.page;
      _productTotalPages = result.totalPages;
      _productTotalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.listAll(page: 1);
      _allMovements = result.items;
      _allPage = result.page;
      _allTotalPages = result.totalPages;
      _allTotalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat riwayat stok.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreAll() async {
    if (_loading || _loadingMore || !hasMoreAll) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final result = await _service.listAll(page: _allPage + 1);
      _allMovements = [..._allMovements, ...result.items];
      _allPage = result.page;
      _allTotalPages = result.totalPages;
      _allTotalItems = result.totalItems;
    } on ApiException catch (exception) {
      _error = exception.message;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<StockMovement> create(
    String productId, {
    required String type,
    required int quantity,
    String? note,
  }) async {
    final movement = await _service.create(
      productId,
      type: type,
      quantity: quantity,
      note: note,
    );
    await loadForProduct(productId);
    return movement;
  }
}
