import '../core/network/api_client.dart';
import '../models/dashboard_summary.dart';

class DashboardService {
  DashboardService(this._client);

  final ApiClient _client;

  Future<DashboardSummary> summary() async {
    final response = await _client.get('/api/dashboard/summary');
    return DashboardSummary.fromJson(response as Map<String, dynamic>);
  }
}
