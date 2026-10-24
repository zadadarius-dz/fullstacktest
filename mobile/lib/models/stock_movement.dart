class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productSku,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.note,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String productSku;
  final String productName;
  final String type;
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final String? note;
  final DateTime? createdAt;

  bool get isIn => type == 'IN';

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id']?.toString() ?? '',
        productId: json['productId']?.toString() ?? '',
        productSku: json['productSku']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        stockBefore: (json['stockBefore'] as num?)?.toInt() ?? 0,
        stockAfter: (json['stockAfter'] as num?)?.toInt() ?? 0,
        note: json['note']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
