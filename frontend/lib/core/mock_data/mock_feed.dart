import '../api/catalog_store.dart';

class TradeSquareMockFeedItem {
  const TradeSquareMockFeedItem({
    required this.id,
    required this.type,
    required this.sourceBusinessId,
    required this.title,
    required this.summary,
    required this.timestamp,
    required this.relevanceExplanation,
    required this.actionMetadata,
  });

  final String id;
  final String type;
  final String sourceBusinessId;
  final String title;
  final String summary;
  final DateTime timestamp;
  final String relevanceExplanation;
  final Map<String, dynamic> actionMetadata;

  factory TradeSquareMockFeedItem.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockFeedItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'product',
      sourceBusinessId: json['sourceBusinessId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      relevanceExplanation: json['relevanceExplanation'] as String? ?? '',
      actionMetadata:
          Map<String, dynamic>.from(json['actionMetadata'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'sourceBusinessId': sourceBusinessId,
        'title': title,
        'summary': summary,
        'timestamp': timestamp.toIso8601String(),
        'relevanceExplanation': relevanceExplanation,
        'actionMetadata': actionMetadata,
      };
}

List<TradeSquareMockFeedItem> get tradeSquareMockFeedItems => CatalogStore.instance.feedItems;
