import '../core/network/api_client.dart';
import '../models/category.dart';

class CategoryService {
  CategoryService(this._client);

  final ApiClient _client;

  Future<List<Category>> list() async {
    final response = await _client.get('/api/categories');
    if (response is! List) return const <Category>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList();
  }

  Future<Category> create(String name) async {
    final response = await _client.post(
      '/api/categories',
      body: {'name': name},
    );
    return Category.fromJson(response as Map<String, dynamic>);
  }
}
