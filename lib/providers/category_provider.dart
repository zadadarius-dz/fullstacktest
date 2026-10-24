import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(ApiClient client) : _service = CategoryService(client);

  final CategoryService _service;

  List<Category> _categories = const <Category>[];
  bool _loading = false;
  String? _error;

  List<Category> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;

  Future<Category?> create(String name) async {
    _error = null;
    notifyListeners();

    try {
      final category = await _service.create(name.trim());
      _categories = [..._categories, category]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return category;
    } on ApiException catch (exception) {
      _error = exception.message;
      return null;
    } catch (_) {
      _error = 'Gagal membuat kategori.';
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && _categories.isNotEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _service.list();
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat kategori.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
