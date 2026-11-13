import '../api/catalog_store.dart';

class TradeSquareMockAnalyticsSummary {
  const TradeSquareMockAnalyticsSummary({
    required this.metric,
    required this.value,
    required this.delta,
    required this.period,
    required this.unit,
  });

  final String metric;
  final num value;
  final num delta;
  final String period;
  final String unit;

  factory TradeSquareMockAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockAnalyticsSummary(
      metric: json['metric'] as String? ?? '',
      value: json['value'] as num? ?? 0,
      delta: json['delta'] as num? ?? 0,
      period: json['period'] as String? ?? '30d',
      unit: json['unit'] as String? ?? '%',
    );
  }

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'value': value,
        'delta': delta,
        'period': period,
        'unit': unit,
      };
}

List<TradeSquareMockAnalyticsSummary> get tradeSquareMockAnalytics => CatalogStore.instance.analytics;
