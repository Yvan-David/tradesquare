import '../mock_data/mock_analytics.dart';
import '../mock_data/mock_business_verification.dart';
import '../mock_data/mock_businesses.dart';
import '../mock_data/mock_buying_requests.dart';
import '../mock_data/mock_categories.dart';
import '../mock_data/mock_connections.dart';
import '../mock_data/mock_feed.dart';
import '../mock_data/mock_messages.dart';
import '../mock_data/mock_notifications.dart';
import '../mock_data/mock_products.dart';
import '../mock_data/mock_users.dart';
import '../../features/marketplace/data/member_marketplace.dart';
import 'tradesquare_api_client.dart';

/// In-memory catalog loaded from `/api/v1/catalog/bootstrap` (Supabase via API).
///
/// Screens must call [ensureLoaded] at app start. Empty lists mean the API/DB
/// is unreachable — never fall back to hard-coded sample rows.
class CatalogStore {
  CatalogStore._();

  static final CatalogStore instance = CatalogStore._();

  TradeSquareApiClient client = TradeSquareApiClient();

  bool loaded = false;
  String? lastError;

  List<TradeSquareMockUser> users = const [];
  List<TradeSquareMockBusiness> businesses = const [];
  List<TradeSquareMockProductListing> products = const [];
  List<TradeSquareMockBuyingRequest> buyingRequests = const [];
  List<TradeSquareMockConnection> connections = const [];
  List<TradeSquareMockBusinessVerification> verifications = const [];
  List<TradeSquareMockCategory> categories = const [];
  List<String> interests = const [];
  List<TradeSquareMockNotification> notifications = const [];
  List<TradeSquareMockFeedItem> feedItems = const [];
  List<TradeSquareMockAnalyticsSummary> analytics = const [];
  List<TradeSquareMockConversation> conversations = const [];

  Future<void> ensureLoaded({bool force = false}) async {
    if (loaded && !force) return;
    try {
      final body = await client.getJson('/api/v1/catalog/bootstrap');
      users = (body['profiles'] as List? ?? const [])
          .map((e) => TradeSquareMockUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      businesses = (body['businesses'] as List? ?? const [])
          .map((e) =>
              TradeSquareMockBusiness.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      products = (body['products'] as List? ?? const [])
          .map((e) => TradeSquareMockProductListing.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      buyingRequests = (body['buyingRequests'] as List? ?? const [])
          .map((e) => TradeSquareMockBuyingRequest.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      connections = (body['connections'] as List? ?? const [])
          .map((e) => TradeSquareMockConnection.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      verifications = (body['verifications'] as List? ?? const [])
          .map((e) => TradeSquareMockBusinessVerification.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      categories = (body['categories'] as List? ?? const [])
          .map((e) =>
              TradeSquareMockCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      interests = List<String>.from(body['interests'] as List? ?? const []);
      notifications = (body['notifications'] as List? ?? const [])
          .map((e) => TradeSquareMockNotification.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      feedItems = (body['feed'] as List? ?? const [])
          .map((e) =>
              TradeSquareMockFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      analytics = (body['analytics'] as List? ?? const [])
          .map((e) => TradeSquareMockAnalyticsSummary.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      conversations = (body['conversations'] as List? ?? const [])
          .map((e) => TradeSquareMockConversation.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      loaded = true;
      lastError = null;
    } catch (error) {
      loaded = false;
      lastError = error.toString();
      users = const [];
      businesses = const [];
      products = const [];
      buyingRequests = const [];
      connections = const [];
      verifications = const [];
      categories = const [];
      interests = const [];
      notifications = const [];
      feedItems = const [];
      analytics = const [];
      conversations = const [];
      rethrow;
    }
  }

  Future<void> createBuyingRequest({
    required String buyerBusinessId,
    required String productOrService,
    required String description,
    required String category,
    required int requiredQuantity,
    required String unit,
    required String deliveryDestination,
    required String urgency,
  }) async {
    final row = await MemberMarketplace().createBuyingRequest(
      buyerBusinessId: buyerBusinessId,
      productOrService: productOrService,
      description: description,
      category: category,
      requiredQuantity: requiredQuantity,
      unit: unit,
      deliveryDestination: deliveryDestination,
      urgency: urgency,
    );
    buyingRequests = [
      TradeSquareMockBuyingRequest.fromJson(row),
      ...buyingRequests,
    ];
  }
}
