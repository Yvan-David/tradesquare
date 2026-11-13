import '../../../core/mock_data/mock_ai_recommendations.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_products.dart';
import '../../home/domain/trade_square_home_feed.dart';
import '../domain/trade_square_discover_models.dart';
import '../domain/trade_square_discover_search.dart';

class TradeSquareMockDiscoverRepository
    implements TradeSquareDiscoverSearchService {
  TradeSquareMockDiscoverRepository({
    TradeSquareDiscoverQueryParser parser = const TradeSquareDiscoverQueryParser(),
    List<TradeSquareMockBusiness>? businesses,
    List<TradeSquareMockProductListing>? products,
    List<TradeSquareMockAiRecommendation>? recommendations,
    this.simulateNetworkDelay = true,
  })  : _parser = parser,
        _businessesOverride = businesses,
        _productsOverride = products,
        _recommendationsOverride = recommendations;

  final TradeSquareDiscoverQueryParser _parser;
  final List<TradeSquareMockBusiness>? _businessesOverride;
  final List<TradeSquareMockProductListing>? _productsOverride;
  final List<TradeSquareMockAiRecommendation>? _recommendationsOverride;
  final bool simulateNetworkDelay;

  List<TradeSquareMockBusiness> get _businesses =>
      _businessesOverride ?? tradeSquareMockBusinesses;
  List<TradeSquareMockProductListing> get _products =>
      _productsOverride ?? tradeSquareMockProducts;
  List<TradeSquareMockAiRecommendation> get _recommendations =>
      _recommendationsOverride ?? tradeSquareMockAiRecommendations;

  static const _priorityMarkets = [
    'Rwanda',
    'Kenya',
    'Uganda',
    'Tanzania',
    'Burundi',
  ];

  static const serviceTransparencyNote =
      'Results use TradeSquare catalog matching rules. Generative AI search connects when the assistant service is available.';

  @override
  Future<TradeSquareDiscoverCatalog> loadCatalog({
    required TradeSquareHomeProfile profile,
  }) async {
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    final all = _businesses
        .map(
          (business) => TradeSquareDiscoverBusinessCard(
            business: business,
            reasons: _profileReasons(profile, business),
          ),
        )
        .toList();

    final personalized = [...all]
      ..sort((a, b) => b.reasons.length.compareTo(a.reasons.length));
    final topPersonalized = personalized
        .where((card) => card.reasons.isNotEmpty)
        .take(6)
        .toList();
    final fallbackPersonalized =
        topPersonalized.isNotEmpty ? topPersonalized : personalized.take(4).toList();

    final aiMatches = <TradeSquareDiscoverBusinessCard>[];
    for (final recommendation in _recommendations) {
      final business = _businessById(recommendation.targetBusinessId);
      if (business == null) continue;
      aiMatches.add(
        TradeSquareDiscoverBusinessCard(
          business: business,
          recommendationLabel: recommendation.recommendationType,
          reasons: [
            ...recommendation.matchingFactors.map((factor) => 'Listed interest: $factor'),
            if (recommendation.explanation.isNotEmpty)
              recommendation.explanation,
          ],
        ),
      );
    }

    // Supplement AI matches from profile overlap when catalog recommendations are sparse.
    if (aiMatches.length < 3) {
      for (final card in fallbackPersonalized) {
        if (aiMatches.any((m) => m.business.id == card.business.id)) continue;
        aiMatches.add(
          TradeSquareDiscoverBusinessCard(
            business: card.business,
            recommendationLabel: 'Potential connection',
            reasons: card.reasons.isEmpty
                ? ['Appears in your regional industry catalog']
                : card.reasons,
          ),
        );
        if (aiMatches.length >= 4) break;
      }
    }

    final productCards = _products.map((product) {
      final business = _businessById(product.businessId);
      return TradeSquareDiscoverProductCard(
        product: product,
        business: business ??
            TradeSquareMockBusiness(
              id: product.businessId,
              name: 'Business',
              logoUrl: '',
              description: '',
              industry: product.industry,
              category: product.category,
              country: product.countryOfOrigin,
              province: '',
              city: product.countryOfOrigin,
              address: '',
              email: '',
              phone: '',
              website: '',
              registrationNumber: '',
              registrationCertificateType: '',
              certificateSubmissionStatus: '',
              verificationStatus: TradeSquareMockVerificationStatus.notSubmitted,
              businessSize: '',
              yearEstablished: 2020,
              productsOffered: const [],
              productsNeeded: const [],
              businessInterests: const [],
              preferredMarkets: const [],
              ownerId: '',
              profileCompleteness: 0,
              createdAt: DateTime.utc(2024),
            ),
        reasons: [
          'Listed under ${product.category}',
          'Origin: ${product.countryOfOrigin}',
          if (product.deliveryLocations.isNotEmpty)
            'Delivers to ${product.deliveryLocations.take(3).join(', ')}',
        ],
      );
    }).toList();

    return TradeSquareDiscoverCatalog(
      personalized: fallbackPersonalized,
      aiMatches: aiMatches,
      markets: _marketSummaries(),
      allBusinesses: all,
      products: productCards,
    );
  }

  @override
  Stream<TradeSquareDiscoverSearchResult> searchJourney({
    required String query,
    required TradeSquareHomeProfile profile,
    TradeSquareDiscoverCategory category =
        TradeSquareDiscoverCategory.businesses,
  }) async* {
    final criteria = _parser.parse(query, category: category);

    yield TradeSquareDiscoverSearchResult(
      criteria: criteria,
      businesses: const [],
      products: const [],
      stage: TradeSquareDiscoverSearchStage.understanding,
      serviceNote: serviceTransparencyNote,
    );
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    yield TradeSquareDiscoverSearchResult(
      criteria: criteria,
      businesses: const [],
      products: const [],
      stage: TradeSquareDiscoverSearchStage.identifying,
      serviceNote: serviceTransparencyNote,
    );
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }

    yield TradeSquareDiscoverSearchResult(
      criteria: criteria,
      businesses: const [],
      products: const [],
      stage: TradeSquareDiscoverSearchStage.searching,
      serviceNote: serviceTransparencyNote,
    );
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }

    yield TradeSquareDiscoverSearchResult(
      criteria: criteria,
      businesses: const [],
      products: const [],
      stage: TradeSquareDiscoverSearchStage.ranking,
      serviceNote: serviceTransparencyNote,
    );
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
    }

    yield await refine(criteria: criteria, profile: profile);
  }

  @override
  Future<TradeSquareDiscoverSearchResult> refine({
    required TradeSquareDiscoverCriteria criteria,
    required TradeSquareHomeProfile profile,
  }) async {
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }

    final businesses = <TradeSquareDiscoverBusinessCard>[];
    for (final business in _businesses) {
      final reasons = _matchReasons(criteria, profile, business);
      if (reasons.isEmpty && criteria.hasInterpretedSignals) continue;
      if (reasons.isEmpty && criteria.rawQuery.isNotEmpty) {
        final blob = _businessBlob(business);
        if (!blob.contains(criteria.rawQuery.toLowerCase())) continue;
        reasons.add('Matches your search terms');
      }
      if (reasons.isEmpty) continue;
      businesses.add(
        TradeSquareDiscoverBusinessCard(
          business: business,
          reasons: reasons,
          recommendationLabel: criteria.activity,
        ),
      );
    }
    businesses.sort((a, b) => b.reasons.length.compareTo(a.reasons.length));

    final products = <TradeSquareDiscoverProductCard>[];
    if (criteria.category == TradeSquareDiscoverCategory.products ||
        criteria.products.isNotEmpty) {
      for (final product in _products) {
        final business = _businessById(product.businessId);
        if (business == null) continue;
        final reasons = _productReasons(criteria, product, business);
        if (reasons.isEmpty) continue;
        products.add(
          TradeSquareDiscoverProductCard(
            product: product,
            business: business,
            reasons: reasons,
          ),
        );
      }
      products.sort((a, b) => b.reasons.length.compareTo(a.reasons.length));
    }

    final empty = businesses.isEmpty && products.isEmpty;
    return TradeSquareDiscoverSearchResult(
      criteria: criteria,
      businesses: businesses,
      products: products,
      stage: empty
          ? TradeSquareDiscoverSearchStage.empty
          : TradeSquareDiscoverSearchStage.ready,
      serviceNote: serviceTransparencyNote,
    );
  }

  List<TradeSquareDiscoverMarketSummary> _marketSummaries() {
    return _priorityMarkets.map((country) {
      final inMarket =
          _businesses.where((business) => business.country == country).toList();
      final industries = inMarket.map((b) => b.industry).toSet().toList()
        ..sort();
      return TradeSquareDiscoverMarketSummary(
        country: country,
        businessCount: inMarket.length,
        industries: industries,
      );
    }).toList();
  }

  List<String> _profileReasons(
    TradeSquareHomeProfile profile,
    TradeSquareMockBusiness business,
  ) {
    final reasons = <String>[];
    final industry = profile.industry?.toLowerCase();
    if (industry != null &&
        industry.isNotEmpty &&
        (business.industry.toLowerCase().contains(industry) ||
            industry.contains(business.industry.toLowerCase()))) {
      reasons.add('Same industry as your profile: ${business.industry}');
    }
    final category = profile.category?.toLowerCase();
    if (category != null &&
        category.isNotEmpty &&
        business.category.toLowerCase().contains(category)) {
      reasons.add('Related category: ${business.category}');
    }
    for (final interest in profile.interests) {
      final match = business.businessInterests.any(
            (item) => item.toLowerCase().contains(interest.toLowerCase()),
          ) ||
          business.productsOffered.any(
            (item) => item.toLowerCase().contains(interest.toLowerCase()),
          ) ||
          business.productsNeeded.any(
            (item) => item.toLowerCase().contains(interest.toLowerCase()),
          );
      if (match) {
        reasons.add('Shared interest: $interest');
      }
    }
    for (final product in profile.productsOffered) {
      if (business.productsNeeded.any(
        (needed) => needed.toLowerCase().contains(product.toLowerCase()),
      )) {
        reasons.add('They need ${product.toLowerCase()}');
      }
    }
    for (final product in profile.productsNeeded) {
      if (business.productsOffered.any(
        (offered) => offered.toLowerCase().contains(product.toLowerCase()),
      )) {
        reasons.add('They offer ${product.toLowerCase()}');
      }
    }
    final location = profile.location?.toLowerCase() ?? '';
    if (location.isNotEmpty &&
        (business.city.toLowerCase().contains(location) ||
            business.country.toLowerCase().contains(location) ||
            location.contains(business.country.toLowerCase()))) {
      reasons.add('Nearby market: ${business.city}, ${business.country}');
    }
    for (final market in profile.targetMarkets) {
      if (business.country.toLowerCase() == market.toLowerCase() ||
          business.preferredMarkets.any(
            (item) => item.toLowerCase() == market.toLowerCase(),
          )) {
        reasons.add('Active around your target market: $market');
      }
    }
    return reasons.toSet().toList();
  }

  List<String> _matchReasons(
    TradeSquareDiscoverCriteria criteria,
    TradeSquareHomeProfile profile,
    TradeSquareMockBusiness business,
  ) {
    final reasons = <String>[];

    for (final product in criteria.products) {
      final needle = product.toLowerCase();
      if (business.productsOffered.any((p) => p.toLowerCase().contains(needle)) ||
          business.productsNeeded.any((p) => p.toLowerCase().contains(needle)) ||
          business.description.toLowerCase().contains(needle) ||
          business.category.toLowerCase().contains(needle) ||
          business.industry.toLowerCase().contains(needle)) {
        reasons.add('Product fit: $product');
      }
    }

    if (criteria.industry != null) {
      final industry = criteria.industry!.toLowerCase();
      if (business.industry.toLowerCase().contains(industry) ||
          industry.contains(business.industry.toLowerCase()) ||
          business.category.toLowerCase().contains(industry)) {
        reasons.add('Industry: ${business.industry}');
      }
    }

    for (final market in criteria.targetMarkets) {
      if (business.country.toLowerCase() == market.toLowerCase()) {
        reasons.add('Based in $market');
      } else if (business.preferredMarkets.any(
        (item) => item.toLowerCase() == market.toLowerCase(),
      )) {
        reasons.add('Lists $market among preferred markets');
      }
    }

    if (criteria.originMarket != null) {
      final origin = criteria.originMarket!.toLowerCase();
      if (business.preferredMarkets.any((item) => item.toLowerCase() == origin) ||
          business.country.toLowerCase() == origin) {
        reasons.add('Connected to ${criteria.originMarket}');
      }
    }

    if (criteria.activity != null) {
      final activity = criteria.activity!.toLowerCase();
      if (activity.contains('buyer') && business.productsNeeded.isNotEmpty) {
        reasons.add('Publishes buying interests');
      }
      if (activity.contains('supplier') && business.productsOffered.isNotEmpty) {
        reasons.add('Publishes products offered');
      }
      if (activity.contains('distributor') &&
          (business.industry.toLowerCase().contains('wholesale') ||
              business.industry.toLowerCase().contains('logistics') ||
              business.category.toLowerCase().contains('distribution'))) {
        reasons.add('Distribution-oriented business profile');
      }
      if (activity.contains('manufacturer') &&
          (business.industry.toLowerCase().contains('manufactur') ||
              business.industry.toLowerCase().contains('packaging') ||
              business.industry.toLowerCase().contains('textile') ||
              business.description.toLowerCase().contains('manufactur'))) {
        reasons.add('Manufacturing profile');
      }
    }

    reasons.addAll(_profileReasons(profile, business).take(2));
    return reasons.toSet().toList();
  }

  List<String> _productReasons(
    TradeSquareDiscoverCriteria criteria,
    TradeSquareMockProductListing product,
    TradeSquareMockBusiness business,
  ) {
    final reasons = <String>[];
    for (final item in criteria.products) {
      final needle = item.toLowerCase();
      if (product.name.toLowerCase().contains(needle) ||
          product.description.toLowerCase().contains(needle) ||
          product.category.toLowerCase().contains(needle)) {
        reasons.add('Product name/category matches “$item”');
      }
    }
    for (final market in criteria.targetMarkets) {
      if (product.deliveryLocations.any(
            (location) => location.toLowerCase().contains(market.toLowerCase()),
          ) ||
          product.countryOfOrigin.toLowerCase() == market.toLowerCase()) {
        reasons.add('Available toward $market');
      }
    }
    if (criteria.industry != null &&
        product.industry.toLowerCase().contains(criteria.industry!.toLowerCase())) {
      reasons.add('Industry: ${product.industry}');
    }
    if (reasons.isEmpty && criteria.rawQuery.isNotEmpty) {
      final blob =
          '${product.name} ${product.description} ${product.category} ${business.name}'
              .toLowerCase();
      if (blob.contains(criteria.rawQuery.toLowerCase())) {
        reasons.add('Matches your search terms');
      }
    }
    return reasons;
  }

  TradeSquareMockBusiness? _businessById(String id) {
    for (final business in _businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  String _businessBlob(TradeSquareMockBusiness business) {
    return [
      business.name,
      business.description,
      business.industry,
      business.category,
      business.country,
      business.city,
      ...business.productsOffered,
      ...business.productsNeeded,
      ...business.businessInterests,
      ...business.preferredMarkets,
    ].join(' ').toLowerCase();
  }
}

/// Convenience accessor used by presentation when no custom service is injected.
TradeSquareDiscoverSearchService createTradeSquareDiscoverSearchService({
  bool simulateNetworkDelay = true,
}) {
  return TradeSquareMockDiscoverRepository(
    simulateNetworkDelay: simulateNetworkDelay,
  );
}
