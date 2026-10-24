import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/movement_provider.dart';
import 'providers/product_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'services/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();

  late final AuthProvider authProvider;
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authProvider.handleUnauthorized(),
  );
  authProvider = AuthProvider(
    tokenStorage: tokenStorage,
    apiClient: apiClient,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => CategoryProvider(apiClient),
        ),
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(apiClient),
        ),
        ChangeNotifierProvider<MovementProvider>(
          create: (_) => MovementProvider(apiClient),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(apiClient),
        ),
      ],
      child: const StockMateApp(),
    ),
  );
}

class StockMateApp extends StatelessWidget {
  const StockMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
