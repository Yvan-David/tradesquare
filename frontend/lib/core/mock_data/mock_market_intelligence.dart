class TradeSquareMockMarketInsight {
  const TradeSquareMockMarketInsight({
    required this.id,
    required this.industry,
    required this.title,
    required this.summary,
    required this.region,
    required this.metricLabel,
    required this.value,
    required this.currency,
    required this.date,
    required this.source,
    required this.isIllustrative,
  });

  final String id;
  final String industry;
  final String title;
  final String summary;
  final String region;
  final String metricLabel;
  final String value;
  final String currency;
  final DateTime date;
  final String source;
  final bool isIllustrative;

  factory TradeSquareMockMarketInsight.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockMarketInsight(
      id: json['id'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      region: json['region'] as String? ?? '',
      metricLabel: json['metricLabel'] as String? ?? '',
      value: json['value'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      date: json['date'] is String
          ? DateTime.tryParse(json['date'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      source: json['source'] as String? ?? 'Illustrative mock data',
      isIllustrative: json['isIllustrative'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'industry': industry,
        'title': title,
        'summary': summary,
        'region': region,
        'metricLabel': metricLabel,
        'value': value,
        'currency': currency,
        'date': date.toIso8601String(),
        'source': source,
        'isIllustrative': isIllustrative,
      };
}

List<TradeSquareMockMarketInsight> get tradeSquareMockMarketInsights => const [];
