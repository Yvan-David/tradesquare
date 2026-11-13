import '../api/catalog_store.dart';

enum TradeSquareMockVerificationState {
  notSubmitted,
  submitted,
  underReview,
  additionalInformationRequired,
  approved,
  rejected,
}

class TradeSquareMockBusinessVerification {
  const TradeSquareMockBusinessVerification({
    required this.businessId,
    required this.status,
    required this.reviewMessage,
    required this.lastUpdated,
  });

  final String businessId;
  final TradeSquareMockVerificationState status;
  final String reviewMessage;
  final DateTime lastUpdated;

  factory TradeSquareMockBusinessVerification.fromJson(
      Map<String, dynamic> json) {
    return TradeSquareMockBusinessVerification(
      businessId: json['businessId'] as String? ?? '',
      status: TradeSquareMockVerificationState.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TradeSquareMockVerificationState.notSubmitted,
      ),
      reviewMessage: json['reviewMessage'] as String? ?? '',
      lastUpdated: json['lastUpdated'] is String
          ? DateTime.tryParse(json['lastUpdated'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'status': status.name,
        'reviewMessage': reviewMessage,
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}

List<TradeSquareMockBusinessVerification> get tradeSquareMockBusinessVerificationStatuses => CatalogStore.instance.verifications;
