import '../core/network/api_client.dart';
import '../models/paged_result.dart';
import '../models/stock_movement.dart';

class MovementService {
  MovementService(this._client);

  final ApiClient _client;

  Future<StockMovement> create(
    String productId, {
    required String type,
    required int quantity,
    String? note,
  }) async {
    final response = await _client.post(
      '/api/products/$productId/movements',
      body: {
        'type': type,
        'quantity': quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return StockMovement.fromJson(response as Map<String, dynamic>);
  }

  Future<PagedResult<StockMovement>> listForProduct(
    String productId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      '/api/products/$productId/movements',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    return PagedResult<StockMovement>.fromJson(
      response as Map<String, dynamic>,
      StockMovement.fromJson,
    );
  }

  Future<PagedResult<StockMovement>> listAll({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      '/api/stock-movements',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    return PagedResult<StockMovement>.fromJson(
      response as Map<String, dynamic>,
      StockMovement.fromJson,
    );
  }
}
