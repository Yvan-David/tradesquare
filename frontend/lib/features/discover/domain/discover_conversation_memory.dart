import 'trade_square_discover_assistant.dart';
import 'trade_square_discover_models.dart';

/// Lightweight in-session memory for follow-ups and corrections.
class DiscoverConversationMemory {
  DiscoverAssistantLanguage? lastLanguage;
  TradeSquareDiscoverCriteria? lastCriteria;
  DiscoverAssistantTool? lastTool;
  String? lastUserText;
  String? lastAssistantText;
  final List<String> recentUserTexts = [];

  void recordUser(String text, DiscoverAssistantLanguage language) {
    lastUserText = text;
    lastLanguage = language;
    recentUserTexts.add(text);
    if (recentUserTexts.length > 8) {
      recentUserTexts.removeAt(0);
    }
  }

  void recordAssistant({
    required String text,
    required DiscoverAssistantTool tool,
    TradeSquareDiscoverCriteria? criteria,
  }) {
    lastAssistantText = text;
    lastTool = tool;
    if (criteria != null) lastCriteria = criteria;
  }

  bool looksLikeFollowUp(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lastCriteria == null && lastTool == null) return false;
    return RegExp(
          r'^(and |also |what about|how about|same|those|them|there|more|na |nona |kandi |na hiyo|et |aussi )',
        ).hasMatch(lower) ||
        RegExp(
          r'\b(same market|same product|another one|more like that|abo|ibindi|mengine|encore)\b',
        ).hasMatch(lower) ||
        lower.length < 28 &&
            !lower.contains('find') &&
            !lower.contains('open') &&
            !lower.contains('ndashaka') &&
            !lower.contains('tafuta');
  }

  bool looksLikeCorrection(String raw) {
    final lower = raw.trim().toLowerCase();
    return RegExp(
      r'\b(no[, ]|not |instead|i meant|actually|rather|si byo|nta|badala yake|non[, ]|plutôt)\b',
    ).hasMatch(lower);
  }

  String mergeFollowUpQuery(String raw) {
    final previous = lastUserText;
    final criteria = lastCriteria;
    if (previous == null && criteria == null) return raw;

    if (looksLikeCorrection(raw)) {
      // Prefer the correction text itself; keep previous markets if absent.
      final markets = criteria?.targetMarkets ?? const <String>[];
      if (markets.isNotEmpty &&
          !raw.toLowerCase().contains(markets.first.toLowerCase())) {
        return '$raw in ${markets.first}';
      }
      return raw;
    }

    if (!looksLikeFollowUp(raw)) return raw;

    final parts = <String>[previous ?? '', raw];
    if (criteria?.targetMarkets.isNotEmpty == true &&
        !raw.toLowerCase().contains(criteria!.targetMarkets.first.toLowerCase())) {
      parts.add(criteria.targetMarkets.first);
    }
    if (criteria?.products.isNotEmpty == true &&
        !raw.toLowerCase().contains(criteria!.products.first.toLowerCase())) {
      parts.add(criteria.products.first);
    }
    return parts.where((part) => part.trim().isNotEmpty).join(' ').trim();
  }

  void clear() {
    lastLanguage = null;
    lastCriteria = null;
    lastTool = null;
    lastUserText = null;
    lastAssistantText = null;
    recentUserTexts.clear();
  }
}
