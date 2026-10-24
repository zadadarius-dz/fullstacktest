import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(ApiClient client) : _service = DashboardService(client);

  final DashboardService _service;

  DashboardSummary? _summary;
  bool _loading = false;
  String? _error;

  DashboardSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _service.summary();
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Gagal memuat ringkasan.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
