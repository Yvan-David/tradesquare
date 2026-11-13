export 'mock_analytics.dart';
export 'mock_ai_recommendations.dart';
export 'mock_authentication.dart';
export 'mock_business_verification.dart';
export 'mock_businesses.dart';
export 'mock_buying_requests.dart';
export 'mock_categories.dart';
export 'mock_connections.dart';
export 'mock_feed.dart';
export 'mock_market_intelligence.dart';
export 'mock_messages.dart';
export 'mock_notifications.dart';
export 'mock_products.dart';
export 'mock_uploads.dart';
export 'mock_users.dart';

import 'package:tradesquare/features/authentication/domain/trade_square_auth_models.dart';
import 'package:tradesquare/features/home/domain/trade_square_home_feed.dart';

import '../api/catalog_store.dart';
import 'mock_businesses.dart';
import 'mock_buying_requests.dart';
import 'mock_categories.dart';
import 'mock_products.dart';

/// Catalog helpers. Sample rows live in Supabase (`supabase/seed.sql`), not here.
class TradeSquareMockData {
  const TradeSquareMockData._();

  static const TradeSquareMockData instance = TradeSquareMockData._();

  static List<TradeSquareMockBusiness> get businesses =>
      tradeSquareMockBusinesses;
  static List<TradeSquareMockProductListing> get products =>
      tradeSquareMockProducts;
  static List<TradeSquareMockBuyingRequest> get buyingRequests =>
      tradeSquareMockBuyingRequests;
  static List<TradeSquareMockCategory> get categories =>
      tradeSquareMockCategories;
  static List<String> get availableInterests {
    final fromDb = CatalogStore.instance.interests;
    if (fromDb.isNotEmpty) return fromDb;
    return const [
      'Packaging',
      'Logistics',
      'Food exports',
      'Renewables',
      'Retail growth',
      'Cold chain',
    ];
  }

  static TradeSquareHomeProfile homeProfileForRole(TradeSquareAccountRole role) {
    final businesses = CatalogStore.instance.businesses.isNotEmpty
        ? CatalogStore.instance.businesses
        : tradeSquareMockBusinesses;
    TradeSquareMockBusiness? pick;
    switch (role) {
      case TradeSquareAccountRole.buyer:
        pick = _byId(businesses, 'biz_002') ??
            businesses
                .where((b) => b.industry.toLowerCase().contains('retail'))
                .firstOrNull;
      case TradeSquareAccountRole.supplier:
        pick = _byId(businesses, 'biz_003') ??
            businesses
                .where((b) => b.industry.toLowerCase().contains('packag'))
                .firstOrNull;
      case TradeSquareAccountRole.both:
        pick = _byId(businesses, 'biz_001') ??
            (businesses.isNotEmpty ? businesses.first : null);
    }
    if (pick == null) {
      return TradeSquareHomeProfile(
        displayName: 'TradeSquare account',
        businessName: 'Your business',
        industry: '',
        category: '',
        businessDescription: '',
        location: '',
        targetMarkets: const [],
        interests: availableInterests.take(3).toList(),
        productsOffered: const [],
        productsNeeded: const [],
        intent: switch (role) {
          TradeSquareAccountRole.buyer => TradeSquareBusinessIntent.buy,
          TradeSquareAccountRole.supplier => TradeSquareBusinessIntent.sell,
          TradeSquareAccountRole.both => TradeSquareBusinessIntent.both,
        },
      );
    }
    return TradeSquareHomeProfile(
      displayName: pick.name,
      businessName: pick.name,
      industry: pick.industry,
      category: pick.category,
      businessDescription: pick.description,
      location: pick.city,
      targetMarkets: pick.preferredMarkets,
      interests: pick.businessInterests,
      productsOffered: pick.productsOffered,
      productsNeeded: pick.productsNeeded,
      intent: switch (role) {
        TradeSquareAccountRole.buyer => TradeSquareBusinessIntent.buy,
        TradeSquareAccountRole.supplier => TradeSquareBusinessIntent.sell,
        TradeSquareAccountRole.both => TradeSquareBusinessIntent.both,
      },
    );
  }

  static TradeSquareMockBusiness? _byId(
    List<TradeSquareMockBusiness> items,
    String id,
  ) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<TradeSquareFeedSection> sectionsForRole(
      TradeSquareAccountRole role) {
    final profile = homeProfileForRole(role);
    final businessById = {
      for (final business in tradeSquareMockBusinesses) business.id: business,
    };

    final opportunities = <TradeSquareFeedOpportunity>[
      for (final product in tradeSquareMockProducts)
        TradeSquareFeedOpportunity(
          id: product.id,
          type: TradeSquareOpportunityType.productListing,
          title: product.name,
          summary: product.description,
          businessName: businessById[product.businessId]?.name ?? '',
          category: product.category,
          industry: product.industry,
          location: businessById[product.businessId]?.city ?? '',
          keywords: [
            product.name,
            product.category,
            ...product.deliveryLocations.take(2),
          ],
          recommendationReasons: const [
            TradeSquareRecommendationReason.productMatch
          ],
          imageUrl: product.productImage,
          createdAt: product.publishedAt,
        ),
      for (final request in tradeSquareMockBuyingRequests)
        TradeSquareFeedOpportunity(
          id: request.id,
          type: TradeSquareOpportunityType.buyerRequest,
          title: request.productOrService,
          summary: request.description,
          businessName: businessById[request.buyerBusinessId]?.name ?? '',
          category: request.category,
          industry: businessById[request.buyerBusinessId]?.industry ?? '',
          location: request.deliveryDestination,
          keywords: [
            request.productOrService,
            request.category,
            request.deliveryDestination,
          ],
          recommendationReasons: const [
            TradeSquareRecommendationReason.locationMatch
          ],
          imageUrl: businessById[request.buyerBusinessId]?.logoUrl ?? '',
          createdAt: request.publishedAt,
        ),
    ];

    final ranked = RuleBasedTradeSquareFeedRanker().rank(
      profile: profile,
      opportunities: opportunities,
      now: DateTime.now().toUtc(),
    );

    final recommendations = ranked
        .where((entry) => entry.relevance > 0)
        .take(6)
        .map((entry) => entry.opportunity)
        .toList();

    return [
      TradeSquareFeedSection(
        type: TradeSquareFeedSectionType.opportunities,
        opportunities: recommendations,
      ),
      TradeSquareFeedSection(
        type: TradeSquareFeedSectionType.buyers,
        opportunities: recommendations
            .where((opportunity) =>
                opportunity.type == TradeSquareOpportunityType.buyerRequest)
            .toList(),
      ),
      TradeSquareFeedSection(
        type: TradeSquareFeedSectionType.products,
        opportunities: recommendations
            .where((opportunity) =>
                opportunity.type == TradeSquareOpportunityType.productListing)
            .toList(),
      ),
    ];
  }
}
