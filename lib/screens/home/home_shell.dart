import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/movement_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../movements/movements_screen.dart';
import '../products/product_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Produk', 'Riwayat Stok'];

  void _onDestinationSelected(int index) {
    setState(() => _index = index);

    if (index == 0) {
      context.read<DashboardProvider>().load();
    } else if (index == 2) {
      context.read<MovementProvider>().loadAll();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari StockMate?'),
        content: const Text('Anda perlu login kembali untuk mengakses data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_index],
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            if (user != null)
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF61736C),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          ProductListScreen(),
          MovementsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_rounded),
            selectedIcon: Icon(Icons.swap_vert_circle_rounded),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}
