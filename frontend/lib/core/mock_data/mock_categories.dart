import '../api/catalog_store.dart';

class TradeSquareMockCategory {
  const TradeSquareMockCategory({
    required this.id,
    required this.name,
    required this.industry,
    required this.description,
  });

  final String id;
  final String name;
  final String industry;
  final String description;

  factory TradeSquareMockCategory.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'industry': industry,
        'description': description,
      };
}

List<TradeSquareMockCategory> get tradeSquareMockCategories => CatalogStore.instance.categories;
