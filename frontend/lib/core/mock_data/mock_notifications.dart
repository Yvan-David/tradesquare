import '../api/catalog_store.dart';

class TradeSquareMockNotification {
  const TradeSquareMockNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.read,
    required this.recipientId,
    required this.destination,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool read;
  final String recipientId;
  final String destination;

  factory TradeSquareMockNotification.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'message',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      read: json['read'] as bool? ?? false,
      recipientId: json['recipientId'] as String? ?? '',
      destination: json['destination'] as String? ?? '/messages',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
        'recipientId': recipientId,
        'destination': destination,
      };
}

List<TradeSquareMockNotification> get tradeSquareMockNotifications => CatalogStore.instance.notifications;
