enum TradeSquareOpportunityType {
  productListing,
  business,
  buyerRequest,
  supplier,
  tradeOpportunity,
  marketInsight,
}

enum TradeSquareFeedSectionType {
  opportunities,
  buyers,
  suppliers,
  products,
  businesses,
  buyingRequests,
  tradeOpportunities,
  marketInsights,
  aiRecommendations,
}

enum TradeSquareBusinessIntent { buy, sell, both }

enum TradeSquareOpportunityStatus { active, expired, unavailable }

enum TradeSquareRecommendationReason {
  industryMatch,
  categoryMatch,
  interestMatch,
  productMatch,
  locationMatch,
  commercialIntentMatch,
  recent,
}

enum TradeSquareRecommendationFeedback {
  save,
  moreLikeThis,
  notInterested,
}

class TradeSquareHomeProfile {
  const TradeSquareHomeProfile({
    this.displayName,
    this.businessName,
    this.industry,
    this.category,
    this.businessDescription,
    this.location,
    this.targetMarkets = const [],
    this.interests = const [],
    this.productsOffered = const [],
    this.productsNeeded = const [],
    this.intent = TradeSquareBusinessIntent.both,
  });

  final String? displayName;
  final String? businessName;
  final String? industry;
  final String? category;
  final String? businessDescription;
  final String? location;
  final List<String> targetMarkets;
  final List<String> interests;
  final List<String> productsOffered;
  final List<String> productsNeeded;
  final TradeSquareBusinessIntent intent;
}

class TradeSquareFeedOpportunity {
  const TradeSquareFeedOpportunity({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    this.businessName,
    this.category,
    this.industry,
    this.location,
    this.keywords = const [],
    this.recommendationReasons = const [],
    this.imageUrl,
    this.createdAt,
    this.expiresAt,
    this.status = TradeSquareOpportunityStatus.active,
    this.isVerified = false,
  });

  final String id;
  final TradeSquareOpportunityType type;
  final String title;
  final String summary;
  final String? businessName;
  final String? category;
  final String? industry;
  final String? location;
  final List<String> keywords;
  final List<TradeSquareRecommendationReason> recommendationReasons;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final TradeSquareOpportunityStatus status;
  final bool isVerified;
}

class TradeSquareFeedSection {
  const TradeSquareFeedSection({
    required this.type,
    required this.opportunities,
  });

  final TradeSquareFeedSectionType type;
  final List<TradeSquareFeedOpportunity> opportunities;
}

class TradeSquareRankedOpportunity {
  const TradeSquareRankedOpportunity({
    required this.opportunity,
    required this.relevance,
    required this.reasons,
  });

  final TradeSquareFeedOpportunity opportunity;

  /// A relative ranking value, not a probability of a successful transaction.
  final double relevance;
  final List<TradeSquareRecommendationReason> reasons;
}

abstract interface class TradeSquareFeedRanker {
  List<TradeSquareRankedOpportunity> rank({
    required TradeSquareHomeProfile profile,
    required Iterable<TradeSquareFeedOpportunity> opportunities,
    required DateTime now,
    Set<String> excludedIds = const {},
  });
}

class RuleBasedTradeSquareFeedRanker implements TradeSquareFeedRanker {
  const RuleBasedTradeSquareFeedRanker({
    this.industryWeight = 3,
    this.interestWeight = 4,
    this.productWeight = 5,
    this.categoryWeight = 3,
    this.locationWeight = 2,
    this.intentWeight = 1,
    this.recentWeight = 1,
  });

  final double industryWeight;
  final double interestWeight;
  final double productWeight;
  final double categoryWeight;
  final double locationWeight;
  final double intentWeight;
  final double recentWeight;

  @override
  List<TradeSquareRankedOpportunity> rank({
    required TradeSquareHomeProfile profile,
    required Iterable<TradeSquareFeedOpportunity> opportunities,
    required DateTime now,
    Set<String> excludedIds = const {},
  }) {
    final interests = _normalized(profile.interests);
    final products = _normalized([
      ...profile.productsOffered,
      ...profile.productsNeeded,
    ]);
    final industry = _normalize(profile.industry);
    final location = _normalize(profile.location);
    final targetMarkets = _normalized(profile.targetMarkets);
    final seen = <String>{};
    final ranked = <TradeSquareRankedOpportunity>[];

    for (final opportunity in opportunities) {
      if (opportunity.id.isEmpty ||
          excludedIds.contains(opportunity.id) ||
          opportunity.status != TradeSquareOpportunityStatus.active ||
          (opportunity.expiresAt != null &&
              !opportunity.expiresAt!.isAfter(now))) {
        continue;
      }
      if (!seen.add(opportunity.id)) continue;

      final reasons = <TradeSquareRecommendationReason>[];
      var relevance = 0.0;
      final candidateIndustry = _normalize(opportunity.industry);
      if (industry.isNotEmpty && candidateIndustry == industry) {
        relevance += industryWeight;
        reasons.add(TradeSquareRecommendationReason.industryMatch);
      }

      final candidateCategory = _normalize(opportunity.category);
      if (candidateCategory.isNotEmpty &&
          candidateCategory == _normalize(profile.category)) {
        relevance += categoryWeight;
        reasons.add(TradeSquareRecommendationReason.categoryMatch);
      }

      final candidateTerms = _normalized([
        if (opportunity.category case final category?) category,
        ...opportunity.keywords,
      ]);
      if (interests.any(candidateTerms.contains)) {
        relevance += interestWeight;
        reasons.add(TradeSquareRecommendationReason.interestMatch);
      }
      if (products.any(candidateTerms.contains)) {
        relevance += productWeight;
        reasons.add(TradeSquareRecommendationReason.productMatch);
      }

      final intentMatches = switch (profile.intent) {
        TradeSquareBusinessIntent.buy =>
          opportunity.type == TradeSquareOpportunityType.supplier ||
              opportunity.type == TradeSquareOpportunityType.productListing,
        TradeSquareBusinessIntent.sell =>
          opportunity.type == TradeSquareOpportunityType.buyerRequest,
        TradeSquareBusinessIntent.both =>
          opportunity.type == TradeSquareOpportunityType.buyerRequest ||
              opportunity.type == TradeSquareOpportunityType.supplier ||
              opportunity.type == TradeSquareOpportunityType.productListing,
      };
      if (intentMatches &&
          reasons.any(
              (reason) => reason != TradeSquareRecommendationReason.recent)) {
        relevance += intentWeight;
        reasons.add(TradeSquareRecommendationReason.commercialIntentMatch);
      }

      if ((location.isNotEmpty &&
              _normalize(opportunity.location) == location) ||
          targetMarkets.contains(_normalize(opportunity.location))) {
        relevance += locationWeight;
        reasons.add(TradeSquareRecommendationReason.locationMatch);
      }

      final createdAt = opportunity.createdAt;
      if (createdAt != null &&
          !createdAt.isAfter(now) &&
          now.difference(createdAt) <= const Duration(days: 7)) {
        relevance += recentWeight;
        reasons.add(TradeSquareRecommendationReason.recent);
      }

      if (reasons
          .any((reason) => reason != TradeSquareRecommendationReason.recent)) {
        ranked.add(TradeSquareRankedOpportunity(
          opportunity: opportunity,
          relevance: relevance,
          reasons: List.unmodifiable(reasons),
        ));
      }
    }

    ranked.sort((a, b) {
      final scoreOrder = b.relevance.compareTo(a.relevance);
      if (scoreOrder != 0) return scoreOrder;
      final dateA = a.opportunity.createdAt;
      final dateB = b.opportunity.createdAt;
      if (dateA == null) return dateB == null ? 0 : 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return List.unmodifiable(ranked);
  }
}

enum TradeSquareFeedInteractionType {
  viewed,
  saved,
  contacted,
  connected,
  requestedMoreLikeThis,
  markedNotInterested,
}

class TradeSquareFeedInteraction {
  const TradeSquareFeedInteraction({
    required this.opportunityId,
    required this.type,
    required this.occurredAt,
  });

  final String opportunityId;
  final TradeSquareFeedInteractionType type;
  final DateTime occurredAt;
}

String _normalize(String? value) => value?.trim().toLowerCase() ?? '';

Set<String> _normalized(Iterable<String> values) =>
    values.map(_normalize).where((value) => value.isNotEmpty).toSet();
