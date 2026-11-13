class TradeSquareMockAiRecommendation {
  const TradeSquareMockAiRecommendation({
    required this.id,
    required this.recommendationType,
    required this.targetBusinessId,
    required this.targetListingId,
    required this.explanation,
    required this.matchingFactors,
    required this.relevanceScore,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String recommendationType;
  final String targetBusinessId;
  final String targetListingId;
  final String explanation;
  final List<String> matchingFactors;
  final double relevanceScore;
  final DateTime createdAt;
  final String status;

  factory TradeSquareMockAiRecommendation.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockAiRecommendation(
      id: json['id'] as String? ?? '',
      recommendationType: json['recommendationType'] as String? ?? 'supplier',
      targetBusinessId: json['targetBusinessId'] as String? ?? '',
      targetListingId: json['targetListingId'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      matchingFactors:
          List<String>.from(json['matchingFactors'] as List? ?? const []),
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recommendationType': recommendationType,
        'targetBusinessId': targetBusinessId,
        'targetListingId': targetListingId,
        'explanation': explanation,
        'matchingFactors': matchingFactors,
        'relevanceScore': relevanceScore,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };
}

List<TradeSquareMockAiRecommendation> get tradeSquareMockAiRecommendations => const [];
