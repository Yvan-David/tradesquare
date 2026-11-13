import 'package:flutter/foundation.dart';

import '../../../core/mock_data/mock_analytics.dart';
import '../../../core/mock_data/mock_business_verification.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_buying_requests.dart';
import '../../../core/mock_data/mock_products.dart';

enum TradeSquareBusinessTab {
  overview,
  products,
  opportunities,
  activity,
}

enum TradeSquareBusinessOpportunityKind {
  buyingRequest,
  supplierOffer,
  partnership,
}

@immutable
class TradeSquareBusinessOpportunityItem {
  const TradeSquareBusinessOpportunityItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.publishedAt,
    required this.summary,
  });

  final String id;
  final String title;
  final TradeSquareBusinessOpportunityKind kind;
  final String status;
  final DateTime publishedAt;
  final String summary;
}

@immutable
class TradeSquareBusinessImprovement {
  const TradeSquareBusinessImprovement({
    required this.id,
    required this.title,
    required this.detail,
    required this.actionLabel,
  });

  final String id;
  final String title;
  final String detail;
  final String actionLabel;
}

@immutable
class TradeSquareBusinessAiSuggestion {
  const TradeSquareBusinessAiSuggestion({
    required this.id,
    required this.title,
    required this.draft,
    required this.contextLabel,
  });

  final String id;
  final String title;
  final String draft;
  final String contextLabel;
}

@immutable
class TradeSquareBusinessActivityMetric {
  const TradeSquareBusinessActivityMetric({
    required this.label,
    required this.valueLabel,
    required this.detail,
  });

  final String label;
  final String valueLabel;
  final String detail;
}

@immutable
class TradeSquareBusinessWorkspace {
  const TradeSquareBusinessWorkspace({
    required this.business,
    required this.coverImageUrl,
    required this.products,
    required this.opportunities,
    required this.verification,
    required this.activity,
    required this.improvements,
    required this.aiSuggestions,
    required this.analytics,
  });

  final TradeSquareMockBusiness business;
  final String coverImageUrl;
  final List<TradeSquareMockProductListing> products;
  final List<TradeSquareBusinessOpportunityItem> opportunities;
  final TradeSquareMockBusinessVerification verification;
  final List<TradeSquareBusinessActivityMetric> activity;
  final List<TradeSquareBusinessImprovement> improvements;
  final List<TradeSquareBusinessAiSuggestion> aiSuggestions;
  final List<TradeSquareMockAnalyticsSummary> analytics;

  bool get isVerified =>
      verification.status == TradeSquareMockVerificationState.approved ||
      business.verificationStatus == TradeSquareMockVerificationStatus.approved;

  TradeSquareBusinessWorkspace copyWith({
    TradeSquareMockBusiness? business,
    String? coverImageUrl,
    List<TradeSquareMockProductListing>? products,
    List<TradeSquareBusinessOpportunityItem>? opportunities,
    TradeSquareMockBusinessVerification? verification,
    List<TradeSquareBusinessActivityMetric>? activity,
    List<TradeSquareBusinessImprovement>? improvements,
    List<TradeSquareBusinessAiSuggestion>? aiSuggestions,
    List<TradeSquareMockAnalyticsSummary>? analytics,
  }) {
    return TradeSquareBusinessWorkspace(
      business: business ?? this.business,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      products: products ?? this.products,
      opportunities: opportunities ?? this.opportunities,
      verification: verification ?? this.verification,
      activity: activity ?? this.activity,
      improvements: improvements ?? this.improvements,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      analytics: analytics ?? this.analytics,
    );
  }
}

String tradeSquareBusinessCoverForIndustry(String industry) {
  final key = industry.toLowerCase();
  if (key.contains('agricultur') || key.contains('food')) {
    return 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=1600&q=80';
  }
  if (key.contains('packag')) {
    return 'https://images.unsplash.com/photo-1553413077-190dd305871c?w=1600&q=80';
  }
  if (key.contains('retail') || key.contains('wholesale')) {
    return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1600&q=80';
  }
  if (key.contains('logistics')) {
    return 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=1600&q=80';
  }
  if (key.contains('manufactur')) {
    return 'https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=1600&q=80';
  }
  return 'https://images.unsplash.com/photo-1556761175-b413da4baf72?w=1600&q=80';
}

List<TradeSquareBusinessOpportunityItem> tradeSquareOpportunitiesFromRecords({
  required String businessId,
  required List<TradeSquareMockBuyingRequest> requests,
  required List<TradeSquareMockProductListing> products,
  required TradeSquareMockBusiness business,
}) {
  final items = <TradeSquareBusinessOpportunityItem>[
    for (final request in requests.where((r) => r.buyerBusinessId == businessId))
      TradeSquareBusinessOpportunityItem(
        id: request.id,
        title: request.productOrService,
        kind: TradeSquareBusinessOpportunityKind.buyingRequest,
        status: request.status,
        publishedAt: request.publishedAt,
        summary: request.description,
      ),
    for (final product in products.where((p) => p.businessId == businessId))
      TradeSquareBusinessOpportunityItem(
        id: 'offer_${product.id}',
        title: product.name,
        kind: TradeSquareBusinessOpportunityKind.supplierOffer,
        status: product.listingStatus,
        publishedAt: product.publishedAt,
        summary: product.description,
      ),
  ];

  if (business.preferredMarkets.isNotEmpty) {
    items.add(
      TradeSquareBusinessOpportunityItem(
        id: 'partner_${business.id}',
        title: 'Partnership outreach · ${business.preferredMarkets.first}',
        kind: TradeSquareBusinessOpportunityKind.partnership,
        status: 'Open',
        publishedAt: business.createdAt,
        summary:
            'Seeking partners across ${business.preferredMarkets.take(3).join(', ')}.',
      ),
    );
  }

  items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return items;
}
