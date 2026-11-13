import '../api/catalog_store.dart';

class TradeSquareMockConnection {
  const TradeSquareMockConnection({
    required this.id,
    required this.requestingBusinessId,
    required this.receivingBusinessId,
    required this.status,
    required this.requestDate,
    required this.relationshipType,
    this.introductoryMessage,
  });

  final String id;
  final String requestingBusinessId;
  final String receivingBusinessId;
  final String status;
  final DateTime requestDate;
  final String relationshipType;
  final String? introductoryMessage;

  factory TradeSquareMockConnection.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockConnection(
      id: json['id'] as String? ?? '',
      requestingBusinessId: json['requestingBusinessId'] as String? ?? '',
      receivingBusinessId: json['receivingBusinessId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requestDate: json['requestDate'] is String
          ? DateTime.tryParse(json['requestDate'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      relationshipType: json['relationshipType'] as String? ?? 'supplier',
      introductoryMessage: json['introductoryMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestingBusinessId': requestingBusinessId,
        'receivingBusinessId': receivingBusinessId,
        'status': status,
        'requestDate': requestDate.toIso8601String(),
        'relationshipType': relationshipType,
        'introductoryMessage': introductoryMessage,
      };
}

List<TradeSquareMockConnection> get tradeSquareMockConnections => CatalogStore.instance.connections;
