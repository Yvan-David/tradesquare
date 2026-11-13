import 'package:flutter/foundation.dart';

import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_products.dart';

enum TradeSquareDiscoverCategory {
  businesses,
  products,
  aiMatches,
  markets,
}

enum TradeSquareDiscoverSearchStage {
  idle,
  understanding,
  identifying,
  searching,
  ranking,
  ready,
  empty,
  error,
}

@immutable
class TradeSquareDiscoverCriteria {
  const TradeSquareDiscoverCriteria({
    this.rawQuery = '',
    this.products = const [],
    this.activity,
    this.originMarket,
    this.targetMarkets = const [],
    this.industry,
    this.category = TradeSquareDiscoverCategory.businesses,
  });

  final String rawQuery;
  final List<String> products;
  final String? activity;
  final String? originMarket;
  final List<String> targetMarkets;
  final String? industry;
  final TradeSquareDiscoverCategory category;

  TradeSquareDiscoverCriteria copyWith({
    String? rawQuery,
    List<String>? products,
    String? activity,
    String? originMarket,
    List<String>? targetMarkets,
    String? industry,
    TradeSquareDiscoverCategory? category,
    bool clearActivity = false,
    bool clearOrigin = false,
    bool clearIndustry = false,
  }) {
    return TradeSquareDiscoverCriteria(
      rawQuery: rawQuery ?? this.rawQuery,
      products: products ?? this.products,
      activity: clearActivity ? null : activity ?? this.activity,
      originMarket: clearOrigin ? null : originMarket ?? this.originMarket,
      targetMarkets: targetMarkets ?? this.targetMarkets,
      industry: clearIndustry ? null : industry ?? this.industry,
      category: category ?? this.category,
    );
  }

  bool get hasInterpretedSignals =>
      products.isNotEmpty ||
      activity != null ||
      originMarket != null ||
      targetMarkets.isNotEmpty ||
      industry != null;
}

@immutable
class TradeSquareDiscoverBusinessCard {
  const TradeSquareDiscoverBusinessCard({
    required this.business,
    required this.reasons,
    this.recommendationLabel,
  });

  final TradeSquareMockBusiness business;
  final List<String> reasons;
  final String? recommendationLabel;

  bool get isVerified =>
      business.verificationStatus == TradeSquareMockVerificationStatus.approved;

  String get locationLabel => '${business.city}, ${business.country}';
}

@immutable
class TradeSquareDiscoverProductCard {
  const TradeSquareDiscoverProductCard({
    required this.product,
    required this.business,
    required this.reasons,
  });

  final TradeSquareMockProductListing product;
  final TradeSquareMockBusiness business;
  final List<String> reasons;
}

@immutable
class TradeSquareDiscoverMarketSummary {
  const TradeSquareDiscoverMarketSummary({
    required this.country,
    required this.businessCount,
    required this.industries,
  });

  final String country;
  final int businessCount;
  final List<String> industries;
}

@immutable
class TradeSquareDiscoverCatalog {
  const TradeSquareDiscoverCatalog({
    required this.personalized,
    required this.aiMatches,
    required this.markets,
    required this.allBusinesses,
    required this.products,
  });

  final List<TradeSquareDiscoverBusinessCard> personalized;
  final List<TradeSquareDiscoverBusinessCard> aiMatches;
  final List<TradeSquareDiscoverMarketSummary> markets;
  final List<TradeSquareDiscoverBusinessCard> allBusinesses;
  final List<TradeSquareDiscoverProductCard> products;
}

@immutable
class TradeSquareDiscoverSearchResult {
  const TradeSquareDiscoverSearchResult({
    required this.criteria,
    required this.businesses,
    required this.products,
    required this.stage,
    this.serviceNote,
  });

  final TradeSquareDiscoverCriteria criteria;
  final List<TradeSquareDiscoverBusinessCard> businesses;
  final List<TradeSquareDiscoverProductCard> products;
  final TradeSquareDiscoverSearchStage stage;
  final String? serviceNote;

  bool get isEmpty => businesses.isEmpty && products.isEmpty;
}

@immutable
class TradeSquareDiscoverIndustry {
  const TradeSquareDiscoverIndustry({
    required this.id,
    required this.label,
    required this.iconName,
    required this.imageUrl,
  });

  final String id;
  final String label;
  final String iconName;
  final String imageUrl;
}

const tradeSquareDiscoverIndustries = <TradeSquareDiscoverIndustry>[
  TradeSquareDiscoverIndustry(
    id: 'agriculture',
    label: 'Agriculture',
    iconName: 'agriculture',
    imageUrl:
        'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'manufacturing',
    label: 'Manufacturing',
    iconName: 'manufacturing',
    imageUrl:
        'https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'technology',
    label: 'Technology',
    iconName: 'technology',
    imageUrl:
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'textiles',
    label: 'Textiles',
    iconName: 'textiles',
    imageUrl:
        'https://images.unsplash.com/photo-1558171813-4c088753af8f?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'logistics',
    label: 'Logistics',
    iconName: 'logistics',
    imageUrl:
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'wholesale',
    label: 'Wholesale',
    iconName: 'wholesale',
    imageUrl:
        'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'food_processing',
    label: 'Food processing',
    iconName: 'food_processing',
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80',
  ),
  TradeSquareDiscoverIndustry(
    id: 'construction',
    label: 'Construction',
    iconName: 'construction',
    imageUrl:
        'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=800&q=80',
  ),
];

const tradeSquareDiscoverHeroImage =
    'https://images.unsplash.com/photo-1556761175-b413da4baf72?w=1600&q=80';

const tradeSquareDiscoverMarketImages = <String, String>{
  'Rwanda':
      'https://images.unsplash.com/photo-1523805009345-7448845a9e53?w=900&q=80',
  'Kenya':
      'https://images.unsplash.com/photo-1489392191049-fc10c97e64b6?w=900&q=80',
  'Uganda':
      'https://images.unsplash.com/photo-1547471080-7cc2caa01a7e?w=900&q=80',
  'Tanzania':
      'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=900&q=80',
  'Burundi':
      'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=900&q=80',
};

const tradeSquareDiscoverExamplePrompts = <String>[
  'Find buyers for my coffee in Kenya.',
  'Find packaging manufacturers in Rwanda.',
  'I need distributors for agricultural products in Uganda.',
  'Find reliable suppliers of raw materials in East Africa.',
  'I manufacture school furniture in Rwanda and want to sell in Uganda.',
];
