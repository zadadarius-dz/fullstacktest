class LowStockItem {
  const LowStockItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.stockQuantity,
    required this.minStock,
  });

  final String id;
  final String sku;
  final String name;
  final int stockQuantity;
  final int minStock;

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
        minStock: (json['minStock'] as num?)?.toInt() ?? 0,
      );
}

class DashboardSummary {
  const DashboardSummary({
    required this.activeProducts,
    required this.categories,
    required this.totalStockUnits,
    required this.lowStockProducts,
    required this.lowStockItems,
  });

  final int activeProducts;
  final int categories;
  final int totalStockUnits;
  final int lowStockProducts;
  final List<LowStockItem> lowStockItems;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['lowStockItems'];
    return DashboardSummary(
      activeProducts: (json['activeProducts'] as num?)?.toInt() ?? 0,
      categories: (json['categories'] as num?)?.toInt() ?? 0,
      totalStockUnits: (json['totalStockUnits'] as num?)?.toInt() ?? 0,
      lowStockProducts: (json['lowStockProducts'] as num?)?.toInt() ?? 0,
      lowStockItems: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(LowStockItem.fromJson)
              .toList()
          : const <LowStockItem>[],
    );
  }
}
