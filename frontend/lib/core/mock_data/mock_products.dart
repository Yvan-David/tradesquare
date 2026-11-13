import '../api/catalog_store.dart';

class TradeSquareMockProductListing {
  const TradeSquareMockProductListing({
    required this.id,
    required this.businessId,
    required this.name,
    required this.productImage,
    required this.description,
    required this.category,
    required this.industry,
    required this.condition,
    required this.unit,
    required this.availableQuantity,
    required this.minimumOrderQuantity,
    required this.indicativePrice,
    required this.currency,
    required this.countryOfOrigin,
    required this.deliveryLocations,
    required this.availabilityStatus,
    required this.listingStatus,
    required this.publishedAt,
    required this.views,
    required this.savedCount,
  });

  final String id;
  final String businessId;
  final String name;
  final String productImage;
  final String description;
  final String category;
  final String industry;
  final String condition;
  final String unit;
  final int availableQuantity;
  final int minimumOrderQuantity;
  final double indicativePrice;
  final String currency;
  final String countryOfOrigin;
  final List<String> deliveryLocations;
  final String availabilityStatus;
  final String listingStatus;
  final DateTime publishedAt;
  final int views;
  final int savedCount;

  factory TradeSquareMockProductListing.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockProductListing(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      productImage: json['productImage'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      condition: json['condition'] as String? ?? 'New',
      unit: json['unit'] as String? ?? 'kg',
      availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
      minimumOrderQuantity:
          (json['minimumOrderQuantity'] as num?)?.toInt() ?? 0,
      indicativePrice: (json['indicativePrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      countryOfOrigin: json['countryOfOrigin'] as String? ?? '',
      deliveryLocations:
          List<String>.from(json['deliveryLocations'] as List? ?? const []),
      availabilityStatus: json['availabilityStatus'] as String? ?? 'In stock',
      listingStatus: json['listingStatus'] as String? ?? 'Active',
      publishedAt: json['publishedAt'] is String
          ? DateTime.tryParse(json['publishedAt'] as String) ??
              DateTime.utc(2024, 1, 1)
          : DateTime.utc(2024, 1, 1),
      views: (json['views'] as num?)?.toInt() ?? 0,
      savedCount: (json['savedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'productImage': productImage,
        'description': description,
        'category': category,
        'industry': industry,
        'condition': condition,
        'unit': unit,
        'availableQuantity': availableQuantity,
        'minimumOrderQuantity': minimumOrderQuantity,
        'indicativePrice': indicativePrice,
        'currency': currency,
        'countryOfOrigin': countryOfOrigin,
        'deliveryLocations': deliveryLocations,
        'availabilityStatus': availabilityStatus,
        'listingStatus': listingStatus,
        'publishedAt': publishedAt.toIso8601String(),
        'views': views,
        'savedCount': savedCount,
      };
}

List<TradeSquareMockProductListing> get tradeSquareMockProducts => CatalogStore.instance.products;
