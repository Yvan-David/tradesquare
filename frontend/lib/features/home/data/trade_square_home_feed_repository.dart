import 'package:tradesquare/core/mock_data/mock_data.dart';
import 'package:tradesquare/features/authentication/domain/trade_square_auth_models.dart';

import '../domain/trade_square_home_feed.dart';

class TradeSquareHomeFeedPage {
  const TradeSquareHomeFeedPage({
    required this.sections,
    this.nextCursor,
  });

  final List<TradeSquareFeedSection> sections;
  final String? nextCursor;
}

abstract interface class TradeSquareHomeFeedRepository {
  Future<TradeSquareHomeFeedPage> fetchFeed({
    required TradeSquareHomeProfile profile,
    String? cursor,
    int pageSize = 20,
  });

  Future<void> updateInterests(List<String> interests);

  Future<void> recordInteraction(TradeSquareFeedInteraction interaction);

  Future<String?> explainRecommendation(String opportunityId);
}

class TradeSquareMockHomeFeedRepository
    implements TradeSquareHomeFeedRepository {
  const TradeSquareMockHomeFeedRepository();

  @override
  Future<TradeSquareHomeFeedPage> fetchFeed({
    required TradeSquareHomeProfile profile,
    String? cursor,
    int pageSize = 20,
  }) async {
    final role = switch (profile.intent) {
      TradeSquareBusinessIntent.buy => TradeSquareAccountRole.buyer,
      TradeSquareBusinessIntent.sell => TradeSquareAccountRole.supplier,
      TradeSquareBusinessIntent.both => TradeSquareAccountRole.both,
    };

    return TradeSquareHomeFeedPage(
      sections: TradeSquareMockData.sectionsForRole(role),
      nextCursor: null,
    );
  }

  @override
  Future<void> updateInterests(List<String> interests) async {}

  @override
  Future<void> recordInteraction(
      TradeSquareFeedInteraction interaction) async {}

  @override
  Future<String?> explainRecommendation(String opportunityId) async {
    return 'This recommendation aligns with your recent product and market interests.';
  }
}
