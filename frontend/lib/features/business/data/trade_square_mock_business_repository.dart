import '../../../core/mock_data/mock_analytics.dart';
import '../../../core/mock_data/mock_business_verification.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_buying_requests.dart';
import '../../../core/mock_data/mock_products.dart';
import '../../authentication/domain/trade_square_auth_models.dart';
import '../../home/domain/trade_square_home_feed.dart';
import '../domain/trade_square_business_workspace.dart';

abstract class TradeSquareBusinessRepository {
  Future<TradeSquareBusinessWorkspace> loadWorkspace({
    required TradeSquareAccountRole role,
    TradeSquareHomeProfile? profile,
  });
}

class TradeSquareMockBusinessRepository implements TradeSquareBusinessRepository {
  TradeSquareMockBusinessRepository({
    List<TradeSquareMockBusiness>? businesses,
    List<TradeSquareMockProductListing>? products,
    List<TradeSquareMockBuyingRequest>? requests,
    List<TradeSquareMockBusinessVerification>? verifications,
    this.simulateNetworkDelay = true,
  })  : _businessesOverride = businesses,
        _productsOverride = products,
        _requestsOverride = requests,
        _verificationsOverride = verifications;

  final List<TradeSquareMockBusiness>? _businessesOverride;
  final List<TradeSquareMockProductListing>? _productsOverride;
  final List<TradeSquareMockBuyingRequest>? _requestsOverride;
  final List<TradeSquareMockBusinessVerification>? _verificationsOverride;
  final bool simulateNetworkDelay;

  List<TradeSquareMockBusiness> get _businesses =>
      _businessesOverride ?? tradeSquareMockBusinesses;
  List<TradeSquareMockProductListing> get _products =>
      _productsOverride ?? tradeSquareMockProducts;
  List<TradeSquareMockBuyingRequest> get _requests =>
      _requestsOverride ?? tradeSquareMockBuyingRequests;
  List<TradeSquareMockBusinessVerification> get _verifications =>
      _verificationsOverride ?? tradeSquareMockBusinessVerificationStatuses;

  @override
  Future<TradeSquareBusinessWorkspace> loadWorkspace({
    required TradeSquareAccountRole role,
    TradeSquareHomeProfile? profile,
  }) async {
    if (simulateNetworkDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    final business = _resolveBusiness(role, profile);
    final products =
        _products.where((item) => item.businessId == business.id).toList();
    final verification = _resolveVerification(business);
    final opportunities = tradeSquareOpportunitiesFromRecords(
      businessId: business.id,
      requests: _requests,
      products: products,
      business: business,
    );

    final productViews =
        products.fold<int>(0, (sum, item) => sum + item.views);
    final productSaves =
        products.fold<int>(0, (sum, item) => sum + item.savedCount);
    final openRequests = opportunities
        .where((item) =>
            item.kind == TradeSquareBusinessOpportunityKind.buyingRequest &&
            item.status.toLowerCase() == 'open')
        .length;

    final activity = <TradeSquareBusinessActivityMetric>[
      TradeSquareBusinessActivityMetric(
        label: 'Product views',
        valueLabel: _formatCount(productViews),
        detail: 'From your published listings',
      ),
      TradeSquareBusinessActivityMetric(
        label: 'Listing saves',
        valueLabel: _formatCount(productSaves),
        detail: 'Buyers saved your products',
      ),
      TradeSquareBusinessActivityMetric(
        label: 'Open opportunities',
        valueLabel: '$openRequests',
        detail: 'Buying requests currently open',
      ),
      TradeSquareBusinessActivityMetric(
        label: 'Profile completeness',
        valueLabel: '${business.profileCompleteness}%',
        detail: 'Based on submitted business details',
      ),
    ];

    // Only include global analytics rows that map to known marketplace metrics.
    final analytics = tradeSquareMockAnalytics
        .where((item) =>
            item.metric == 'Product views' ||
            item.metric == 'Connection requests')
        .toList();

    return TradeSquareBusinessWorkspace(
      business: business,
      coverImageUrl: tradeSquareBusinessCoverForIndustry(business.industry),
      products: products,
      opportunities: opportunities,
      verification: verification,
      activity: activity,
      improvements: _improvementsFor(business, products, verification),
      aiSuggestions: _aiSuggestionsFor(business, products),
      analytics: analytics,
    );
  }

  TradeSquareMockBusiness _resolveBusiness(
    TradeSquareAccountRole role,
    TradeSquareHomeProfile? profile,
  ) {
    final preferredName = profile?.businessName;
    if (preferredName != null) {
      for (final business in _businesses) {
        if (business.name == preferredName) return business;
      }
    }

    final ownerId = switch (role) {
      TradeSquareAccountRole.buyer => 'usr_002',
      TradeSquareAccountRole.supplier => 'usr_003',
      TradeSquareAccountRole.both => 'usr_001',
    };
    for (final business in _businesses) {
      if (business.ownerId == ownerId) return business;
    }
    return _businesses.first;
  }

  TradeSquareMockBusinessVerification _resolveVerification(
    TradeSquareMockBusiness business,
  ) {
    for (final item in _verifications) {
      if (item.businessId == business.id) return item;
    }
    return TradeSquareMockBusinessVerification(
      businessId: business.id,
      status: switch (business.verificationStatus) {
        TradeSquareMockVerificationStatus.approved =>
          TradeSquareMockVerificationState.approved,
        TradeSquareMockVerificationStatus.underReview =>
          TradeSquareMockVerificationState.underReview,
        TradeSquareMockVerificationStatus.submitted =>
          TradeSquareMockVerificationState.submitted,
        TradeSquareMockVerificationStatus.additionalInformationRequired =>
          TradeSquareMockVerificationState.additionalInformationRequired,
        TradeSquareMockVerificationStatus.rejected =>
          TradeSquareMockVerificationState.rejected,
        TradeSquareMockVerificationStatus.notSubmitted =>
          TradeSquareMockVerificationState.notSubmitted,
      },
      reviewMessage: business.certificateSubmissionStatus,
      lastUpdated: business.createdAt,
    );
  }

  List<TradeSquareBusinessImprovement> _improvementsFor(
    TradeSquareMockBusiness business,
    List<TradeSquareMockProductListing> products,
    TradeSquareMockBusinessVerification verification,
  ) {
    final items = <TradeSquareBusinessImprovement>[];
    if (business.description.trim().length < 80) {
      items.add(
        const TradeSquareBusinessImprovement(
          id: 'desc',
          title: 'Strengthen your business story',
          detail:
              'Add a clearer description of what you sell, who you serve and where you operate.',
          actionLabel: 'Improve description',
        ),
      );
    }
    if (products.isEmpty) {
      items.add(
        const TradeSquareBusinessImprovement(
          id: 'products',
          title: 'Publish your first product',
          detail:
              'Listings help buyers and partners find you in Discover and Opportunities.',
          actionLabel: 'Add product',
        ),
      );
    }
    if (business.preferredMarkets.isEmpty) {
      items.add(
        const TradeSquareBusinessImprovement(
          id: 'markets',
          title: 'Add markets you serve',
          detail: 'Tell TradeSquare which countries or cities you can supply.',
          actionLabel: 'Edit markets',
        ),
      );
    }
    if (verification.status != TradeSquareMockVerificationState.approved) {
      items.add(
        TradeSquareBusinessImprovement(
          id: 'verify',
          title: 'Complete business verification',
          detail: verification.reviewMessage.isEmpty
              ? 'Submit registration documents to unlock the verified badge.'
              : verification.reviewMessage,
          actionLabel: 'Review verification',
        ),
      );
    }
    if (business.website.trim().isEmpty) {
      items.add(
        const TradeSquareBusinessImprovement(
          id: 'website',
          title: 'Add a website or contact channel',
          detail: 'Make it easy for partners to learn more about your company.',
          actionLabel: 'Edit business',
        ),
      );
    }
    return items;
  }

  List<TradeSquareBusinessAiSuggestion> _aiSuggestionsFor(
    TradeSquareMockBusiness business,
    List<TradeSquareMockProductListing> products,
  ) {
    return [
      TradeSquareBusinessAiSuggestion(
        id: 'ai_desc',
        title: 'Improved business description',
        contextLabel: 'Profile copy',
        draft:
            '${business.name} is a ${business.industry.toLowerCase()} business based in ${business.city}, ${business.country}. '
            'We focus on ${business.productsOffered.take(3).join(', ').toLowerCase()} and serve partners across '
            '${business.preferredMarkets.take(3).join(', ')}.',
      ),
      if (products.isNotEmpty)
        TradeSquareBusinessAiSuggestion(
          id: 'ai_product',
          title: 'Clearer product description',
          contextLabel: products.first.name,
          draft:
              '${products.first.name} from ${business.name}: ${products.first.description} '
              'Available for delivery to ${products.first.deliveryLocations.take(3).join(', ')}.',
        ),
      TradeSquareBusinessAiSuggestion(
        id: 'ai_request',
        title: 'Draft buying request',
        contextLabel: 'Opportunity',
        draft: business.productsNeeded.isEmpty
            ? 'Looking for reliable partners to support expansion in ${business.preferredMarkets.take(2).join(' and ')}.'
            : 'Looking to source ${business.productsNeeded.first.toLowerCase()} for operations in ${business.city}, ${business.country}.',
      ),
    ];
  }

  String _formatCount(int value) {
    if (value >= 1000) {
      final compact = value / 1000;
      return compact >= 10
          ? '${compact.round()}k'
          : '${compact.toStringAsFixed(1)}k';
    }
    return '$value';
  }
}
