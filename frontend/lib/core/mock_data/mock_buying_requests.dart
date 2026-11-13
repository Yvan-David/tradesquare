import '../api/catalog_store.dart';

class TradeSquareMockBuyingRequest {
  const TradeSquareMockBuyingRequest({
    required this.id,
    required this.buyerBusinessId,
    required this.productOrService,
    required this.description,
    required this.category,
    required this.requiredQuantity,
    required this.unit,
    required this.targetPriceRange,
    required this.currency,
    required this.deliveryDestination,
    required this.preferredSupplierLocation,
    required this.deadline,
    required this.urgency,
    required this.status,
    required this.publishedAt,
  });

  final String id;
  final String buyerBusinessId;
  final String productOrService;
  final String description;
  final String category;
  final int requiredQuantity;
  final String unit;
  final String targetPriceRange;
  final String currency;
  final String deliveryDestination;
  final String preferredSupplierLocation;
  final DateTime deadline;
  final String urgency;
  final String status;
  final DateTime publishedAt;

  factory TradeSquareMockBuyingRequest.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockBuyingRequest(
      id: json['id'] as String? ?? '',
      buyerBusinessId: json['buyerBusinessId'] as String? ?? '',
      productOrService: json['productOrService'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      requiredQuantity: (json['requiredQuantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'kg',
      targetPriceRange: json['targetPriceRange'] as String? ?? '',
      currency: json['currency'] as String? ?? 'USD',
      deliveryDestination: json['deliveryDestination'] as String? ?? '',
      preferredSupplierLocation:
          json['preferredSupplierLocation'] as String? ?? '',
      deadline: json['deadline'] is String
          ? DateTime.tryParse(json['deadline'] as String) ??
              DateTime.utc(2026, 12, 1)
          : DateTime.utc(2026, 12, 1),
      urgency: json['urgency'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'Open',
      publishedAt: json['publishedAt'] is String
          ? DateTime.tryParse(json['publishedAt'] as String) ??
              DateTime.utc(2026, 10, 1)
          : DateTime.utc(2026, 10, 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyerBusinessId': buyerBusinessId,
        'productOrService': productOrService,
        'description': description,
        'category': category,
        'requiredQuantity': requiredQuantity,
        'unit': unit,
        'targetPriceRange': targetPriceRange,
        'currency': currency,
        'deliveryDestination': deliveryDestination,
        'preferredSupplierLocation': preferredSupplierLocation,
        'deadline': deadline.toIso8601String(),
        'urgency': urgency,
        'status': status,
        'publishedAt': publishedAt.toIso8601String(),
      };
}

List<TradeSquareMockBuyingRequest> get tradeSquareMockBuyingRequests => CatalogStore.instance.buyingRequests;
