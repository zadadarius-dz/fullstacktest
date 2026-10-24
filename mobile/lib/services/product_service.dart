import '../core/network/api_client.dart';
import '../models/paged_result.dart';
import '../models/product.dart';

class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  Future<PagedResult<Product>> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    String categoryId = '',
    bool lowStock = false,
  }) async {
    final response = await _client.get(
      '/api/products',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'search': search,
        'categoryId': categoryId,
        'lowStock': lowStock ? 'true' : null,
      },
    );
    return PagedResult<Product>.fromJson(
      response as Map<String, dynamic>,
      Product.fromJson,
    );
  }

  Future<Product> get(String id) async {
    final response = await _client.get('/api/products/$id');
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<Product> create(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/products', body: payload);
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<Product> update(String id, Map<String, dynamic> payload) async {
    final response = await _client.put('/api/products/$id', body: payload);
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.delete('/api/products/$id');
}
