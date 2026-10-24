class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.stockQuantity,
    required this.minStock,
    required this.isActive,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sku;
  final String name;
  final String categoryId;
  final String categoryName;
  final String? description;
  final double price;
  final int stockQuantity;
  final int minStock;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stockQuantity <= minStock;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        categoryId: json['categoryId']?.toString() ?? '',
        categoryName: json['categoryName']?.toString() ?? '',
        description: json['description']?.toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
        minStock: (json['minStock'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}
