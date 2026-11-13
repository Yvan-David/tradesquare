import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/features/home/domain/trade_square_home_feed.dart';

void main() {
  const ranker = RuleBasedTradeSquareFeedRanker();
  final now = DateTime.utc(2026, 11, 10);
  const profile = TradeSquareHomeProfile(
    industry: 'Agriculture',
    category: 'Food production',
    location: 'Kigali',
    targetMarkets: ['Nairobi'],
    interests: ['Packaging'],
    productsOffered: ['Rice'],
    productsNeeded: ['Fertilizer'],
    intent: TradeSquareBusinessIntent.both,
  );

  test('ranks relevant cross-industry trade before industry-only content', () {
    const crossIndustry = TradeSquareFeedOpportunity(
      id: 'cross-industry',
      type: TradeSquareOpportunityType.supplier,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      industry: 'Packaging',
      category: 'Packaging',
      keywords: ['Packaging', 'Fertilizer'],
      location: 'Nairobi',
    );
    const sameIndustry = TradeSquareFeedOpportunity(
      id: 'same-industry',
      type: TradeSquareOpportunityType.business,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      industry: 'Agriculture',
    );

    final ranked = ranker.rank(
      profile: profile,
      opportunities: [sameIndustry, crossIndustry],
      now: now,
    );

    expect(ranked.map((item) => item.opportunity.id).toList(),
        ['cross-industry', 'same-industry']);
    expect(
      ranked.first.reasons,
      contains(TradeSquareRecommendationReason.productMatch),
    );
  });

  test('omits expired, unavailable, duplicate, excluded and unrelated content',
      () {
    const eligible = TradeSquareFeedOpportunity(
      id: 'eligible',
      type: TradeSquareOpportunityType.productListing,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      keywords: ['Rice'],
    );
    final expired = TradeSquareFeedOpportunity(
      id: 'expired',
      type: TradeSquareOpportunityType.productListing,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      keywords: ['Rice'],
      expiresAt: DateTime.utc(2026, 11, 9),
    );
    const unavailable = TradeSquareFeedOpportunity(
      id: 'unavailable',
      type: TradeSquareOpportunityType.productListing,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      keywords: ['Rice'],
      status: TradeSquareOpportunityStatus.unavailable,
    );
    const unrelated = TradeSquareFeedOpportunity(
      id: 'unrelated',
      type: TradeSquareOpportunityType.business,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      industry: 'Unrelated industry',
      location: 'Unrelated location',
    );

    final ranked = ranker.rank(
      profile: profile,
      opportunities: [eligible, eligible, expired, unavailable, unrelated],
      now: now,
      excludedIds: const {'eligible'},
    );

    expect(ranked, isEmpty);
  });

  test('uses target markets and drops future-dated listings', () {
    final targetMarket = TradeSquareFeedOpportunity(
      id: 'target-market',
      type: TradeSquareOpportunityType.business,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      location: 'Nairobi',
      createdAt: DateTime.utc(2026, 11, 11),
    );

    final ranked = ranker.rank(
      profile: profile,
      opportunities: [targetMarket],
      now: now,
    );

    expect(ranked, hasLength(1));
    expect(
      ranked.single.reasons,
      contains(TradeSquareRecommendationReason.locationMatch),
    );
    expect(
      ranked.single.reasons,
      isNot(contains(TradeSquareRecommendationReason.recent)),
    );
  });

  test('an expired duplicate does not suppress its active counterpart', () {
    final expired = TradeSquareFeedOpportunity(
      id: 'same-id',
      type: TradeSquareOpportunityType.productListing,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      keywords: const ['Rice'],
      expiresAt: DateTime.utc(2026, 11, 9),
    );
    const active = TradeSquareFeedOpportunity(
      id: 'same-id',
      type: TradeSquareOpportunityType.productListing,
      title: 'Opportunity title',
      summary: 'Opportunity summary',
      keywords: ['Rice'],
    );

    final ranked = ranker.rank(
      profile: profile,
      opportunities: [expired, active],
      now: now,
    );

    expect(ranked, hasLength(1));
    expect(
        ranked.single.opportunity.status, TradeSquareOpportunityStatus.active);
  });
}
