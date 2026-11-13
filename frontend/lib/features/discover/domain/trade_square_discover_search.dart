import 'trade_square_discover_models.dart';
import '../../home/domain/trade_square_home_feed.dart';

/// Integration boundary for Discover search.
///
/// Implementations may call a remote AI service later. The UI must not assume
/// generative AI is live — mock implementations are rule-based over catalog data.
abstract class TradeSquareDiscoverSearchService {
  Future<TradeSquareDiscoverCatalog> loadCatalog({
    required TradeSquareHomeProfile profile,
  });

  Stream<TradeSquareDiscoverSearchResult> searchJourney({
    required String query,
    required TradeSquareHomeProfile profile,
    TradeSquareDiscoverCategory category =
        TradeSquareDiscoverCategory.businesses,
  });

  Future<TradeSquareDiscoverSearchResult> refine({
    required TradeSquareDiscoverCriteria criteria,
    required TradeSquareHomeProfile profile,
  });
}

class TradeSquareDiscoverQueryParser {
  const TradeSquareDiscoverQueryParser();

  static const _markets = <String>[
    'Rwanda',
    'Kenya',
    'Uganda',
    'Tanzania',
    'Burundi',
    'East Africa',
    'DR Congo',
  ];

  static const _industries = <String>[
    'Agriculture',
    'Manufacturing',
    'Technology',
    'Textiles',
    'Logistics',
    'Wholesale',
    'Food processing',
    'Construction',
    'Packaging',
    'Retail & wholesale',
    'Renewable energy',
  ];

  static const _productHints = <String>[
    'coffee',
    'packaging',
    'carton',
    'cartons',
    'rice',
    'beans',
    'vegetables',
    'avocado',
    'avocados',
    'furniture',
    'school furniture',
    'desks',
    'uniforms',
    'textiles',
    'solar',
    'freight',
    'logistics',
    'cement',
    'maize',
    'raw materials',
    'agricultural products',
    // Kinyarwanda / Kiswahili / French business terms mapped to catalog hints
    'ibigori',
    'umuceri',
    'ikawa',
    'emballages',
    'emballage',
    'kahawa',
    'mahindi',
    'mpunga',
  ];

  static const _productAliases = <String, String>{
    'ibigori': 'Maize',
    'mahindi': 'Maize',
    'umuceri': 'Rice',
    'mpunga': 'Rice',
    'ikawa': 'Coffee',
    'kahawa': 'Coffee',
    'emballages': 'Packaging',
    'emballage': 'Packaging',
  };

  TradeSquareDiscoverCriteria parse(
    String rawQuery, {
    TradeSquareDiscoverCategory category =
        TradeSquareDiscoverCategory.businesses,
  }) {
    final query = rawQuery.trim();
    final lower = query.toLowerCase();

    String? activity;
    if (RegExp(
          r'\b(buy|buyer|buyers|purchase|sourcing|acheteurs?|wanunuzi|abaguzi|umuguzi)\b',
        ).hasMatch(lower) ||
        lower.contains('kubona abaguzi') ||
        lower.contains('tafuta wanunuzi')) {
      activity = 'Find buyers';
    } else if (RegExp(
          r'\b(sell|selling|supplier|suppliers|supply|fournisseurs?|wasambazaji|abatanga)\b',
        ).hasMatch(lower) ||
        lower.contains('tafuta wasambazaji')) {
      activity = 'Find suppliers';
    } else if (RegExp(r'\b(distribut|distributor|distributors)\b')
        .hasMatch(lower)) {
      activity = 'Find distributors';
    } else if (RegExp(r'\b(manufactur|factory|produce|producer)\b')
        .hasMatch(lower)) {
      activity = 'Find manufacturers';
    } else if (RegExp(
          r'\b(partner|partnership|connection|connect|partenariat|ubufatanye|ushirikiano)\b',
        ).hasMatch(lower)) {
      activity = 'Find partners';
    }

    String? origin;
    final originMatch = RegExp(
      r'\bin\s+(rwanda|kenya|uganda|tanzania|burundi)\b.*\b(want to sell|sell to|export to|for)\b',
      caseSensitive: false,
    ).firstMatch(query);
    if (originMatch != null) {
      origin = _capitalizeMarket(originMatch.group(1)!);
    } else {
      final manufactureIn = RegExp(
        r'\b(?:manufacture|manufacturing|based|from|in)\s+(rwanda|kenya|uganda|tanzania|burundi)\b',
        caseSensitive: false,
      ).firstMatch(query);
      if (manufactureIn != null &&
          RegExp(r'\b(sell|export|want to sell)\b', caseSensitive: false)
              .hasMatch(query)) {
        origin = _capitalizeMarket(manufactureIn.group(1)!);
      }
    }

    final targets = <String>[];
    for (final market in _markets) {
      if (lower.contains(market.toLowerCase())) {
        if (origin != null && market.toLowerCase() == origin.toLowerCase()) {
          continue;
        }
        if (market == 'East Africa') {
          targets.addAll(['Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'Burundi']);
        } else {
          targets.add(market);
        }
      }
    }
    final uniqueTargets = targets.toSet().toList();

    // Prefer explicit destination phrasing.
    final sellIn = RegExp(
      r'\b(?:sell in|export to|for)\s+(rwanda|kenya|uganda|tanzania|burundi|east africa)\b',
      caseSensitive: false,
    ).firstMatch(query);
    if (sellIn != null) {
      final market = _capitalizeMarket(sellIn.group(1)!);
      if (market == 'East Africa') {
        uniqueTargets
          ..clear()
          ..addAll(['Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'Burundi']);
      } else if (!uniqueTargets.contains(market)) {
        uniqueTargets.insert(0, market);
      }
    }

    final products = <String>[];
    for (final hint in _productHints) {
      if (lower.contains(hint)) {
        final mapped = _productAliases[hint] ?? _titleCase(hint);
        if (!products.any((p) => p.toLowerCase() == mapped.toLowerCase())) {
          products.add(mapped);
        }
      }
    }

    // Multilingual market phrasing: "muri Kenya", "nchini Kenya", "au Kenya"
    final multilingualMarket = RegExp(
      r'\b(?:muri|nchini|au|en|in)\s+(rwanda|kenya|uganda|tanzania|burundi)\b',
      caseSensitive: false,
    ).firstMatch(query);
    if (multilingualMarket != null) {
      final market = _capitalizeMarket(multilingualMarket.group(1)!);
      if (!uniqueTargets.contains(market)) {
        uniqueTargets.insert(0, market);
      }
    }

    String? industry;
    for (final item in _industries) {
      if (lower.contains(item.toLowerCase())) {
        industry = item;
        break;
      }
    }
    if (industry == null) {
      if (products.any((p) =>
          p.toLowerCase().contains('furniture') ||
          p.toLowerCase().contains('desk'))) {
        industry = 'Manufacturing';
      } else if (products.any((p) =>
          p.toLowerCase().contains('packaging') ||
          p.toLowerCase().contains('carton'))) {
        industry = 'Packaging';
      } else if (products.any((p) =>
          p.toLowerCase().contains('coffee') ||
          p.toLowerCase().contains('rice') ||
          p.toLowerCase().contains('agricultural'))) {
        industry = 'Agriculture';
      } else if (products.any((p) => p.toLowerCase().contains('uniform'))) {
        industry = 'Textiles';
      }
    }

    return TradeSquareDiscoverCriteria(
      rawQuery: query,
      products: products,
      activity: activity,
      originMarket: origin,
      targetMarkets: uniqueTargets,
      industry: industry,
      category: category,
    );
  }

  String _capitalizeMarket(String value) {
    final lower = value.toLowerCase();
    if (lower == 'east africa') return 'East Africa';
    if (lower == 'dr congo') return 'DR Congo';
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
