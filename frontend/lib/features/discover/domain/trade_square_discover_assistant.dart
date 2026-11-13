import 'package:flutter/foundation.dart';

import '../../../core/mock_data/mock_businesses.dart';
import 'trade_square_discover_models.dart';

enum DiscoverVoiceUiState {
  idle,
  listening,
  transcribing,
  thinking,
  speaking,
  interrupted,
  error,
}

enum DiscoverAssistantLanguage {
  english,
  kinyarwanda,
  kiswahili,
  french,
}

enum DiscoverChatRole { user, assistant, system }

enum DiscoverAssistantTool {
  searchBusinesses,
  searchOpportunities,
  openMessages,
  openBusinessProfile,
  openOpportunities,
  openHome,
  draftBuyingRequest,
  improveBusinessDescription,
  translateText,
  none,
}

@immutable
class DiscoverAssistantAction {
  const DiscoverAssistantAction({
    required this.tool,
    required this.label,
    this.payload = const {},
    this.requiresConfirmation = false,
  });

  final DiscoverAssistantTool tool;
  final String label;
  final Map<String, String> payload;
  final bool requiresConfirmation;
}

@immutable
class DiscoverChatMessage {
  const DiscoverChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.language = DiscoverAssistantLanguage.english,
    this.isStreaming = false,
    this.businesses = const [],
    this.products = const [],
    this.actions = const [],
    this.serviceNote,
    this.transcriptionPartial = false,
  });

  final String id;
  final DiscoverChatRole role;
  final String text;
  final DateTime createdAt;
  final DiscoverAssistantLanguage language;
  final bool isStreaming;
  final List<TradeSquareDiscoverBusinessCard> businesses;
  final List<TradeSquareDiscoverProductCard> products;
  final List<DiscoverAssistantAction> actions;
  final String? serviceNote;
  final bool transcriptionPartial;

  DiscoverChatMessage copyWith({
    String? text,
    bool? isStreaming,
    List<TradeSquareDiscoverBusinessCard>? businesses,
    List<TradeSquareDiscoverProductCard>? products,
    List<DiscoverAssistantAction>? actions,
    String? serviceNote,
    bool? transcriptionPartial,
  }) {
    return DiscoverChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      language: language,
      isStreaming: isStreaming ?? this.isStreaming,
      businesses: businesses ?? this.businesses,
      products: products ?? this.products,
      actions: actions ?? this.actions,
      serviceNote: serviceNote ?? this.serviceNote,
      transcriptionPartial: transcriptionPartial ?? this.transcriptionPartial,
    );
  }
}

@immutable
class DiscoverAssistantTurn {
  const DiscoverAssistantTurn({
    required this.userText,
    required this.language,
    required this.replyText,
    required this.tool,
    this.criteria,
    this.businesses = const [],
    this.products = const [],
    this.actions = const [],
    this.serviceNote,
    this.navigationTarget,
    this.draftContent,
  });

  final String userText;
  final DiscoverAssistantLanguage language;
  final String replyText;
  final DiscoverAssistantTool tool;
  final TradeSquareDiscoverCriteria? criteria;
  final List<TradeSquareDiscoverBusinessCard> businesses;
  final List<TradeSquareDiscoverProductCard> products;
  final List<DiscoverAssistantAction> actions;
  final String? serviceNote;
  final String? navigationTarget;
  final String? draftContent;
}

class DiscoverLanguageDetector {
  const DiscoverLanguageDetector();

  DiscoverAssistantLanguage detect(String raw, {String? localeHint}) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) {
      return _fromLocale(localeHint);
    }

    final rwHits = _countHits(text, const [
      'ndashaka',
      'nfite',
      'muri ',
      ' abaguzi',
      'abaguzi',
      'umuguzi',
      'abatanga',
      'ibigori',
      'umuceri',
      'ubucuruzi',
      'amahirwe',
      'gushakisha',
      'muraho',
      'mwiriwe',
      'kubona',
      'ubufatanye',
      'ibicuruzwa',
      'serivisi',
      'mfasha',
      'ndagufungurira',
    ]);
    final swHits = _countHits(text, const [
      'nataka',
      'tafuta',
      'wanunuzi',
      'wasambazaji',
      'biashara',
      'nchini',
      'kahawa',
      'mahindi',
      'wasiliana',
      'habari',
      'tafadhali',
      'bidhaa',
      'wasambaza',
    ]);
    final frHits = _countHits(text, const [
      'acheter',
      'acheteurs',
      'fournisseurs',
      'trouver',
      'entreprises',
      'emballages',
      'partenariat',
      'bonjour',
      'cherche',
      'je veux',
      'marché',
      'opportunité',
    ]);

    if (rwHits >= 1 && rwHits >= swHits && rwHits >= frHits) {
      return DiscoverAssistantLanguage.kinyarwanda;
    }
    if (swHits >= 1 && swHits >= frHits) {
      return DiscoverAssistantLanguage.kiswahili;
    }
    if (frHits >= 1) {
      return DiscoverAssistantLanguage.french;
    }
    return DiscoverAssistantLanguage.english;
  }

  int _countHits(String text, List<String> tokens) {
    var count = 0;
    for (final token in tokens) {
      if (text.contains(token)) count += 1;
    }
    return count;
  }

  DiscoverAssistantLanguage _fromLocale(String? localeHint) {
    switch (localeHint?.toLowerCase()) {
      case 'rw':
        return DiscoverAssistantLanguage.kinyarwanda;
      case 'sw':
        return DiscoverAssistantLanguage.kiswahili;
      case 'fr':
        return DiscoverAssistantLanguage.french;
      default:
        return DiscoverAssistantLanguage.english;
    }
  }
}

String discoverLanguageCode(DiscoverAssistantLanguage language) {
  return switch (language) {
    DiscoverAssistantLanguage.english => 'en',
    DiscoverAssistantLanguage.kinyarwanda => 'rw',
    DiscoverAssistantLanguage.kiswahili => 'sw',
    DiscoverAssistantLanguage.french => 'fr',
  };
}

String discoverSpeechLocaleId(DiscoverAssistantLanguage language) {
  return switch (language) {
    DiscoverAssistantLanguage.english => 'en_US',
    DiscoverAssistantLanguage.kinyarwanda => 'rw-RW',
    DiscoverAssistantLanguage.kiswahili => 'sw-KE',
    DiscoverAssistantLanguage.french => 'fr-FR',
  };
}

String discoverTtsLocaleId(DiscoverAssistantLanguage language) {
  return switch (language) {
    DiscoverAssistantLanguage.english => 'en-US',
    DiscoverAssistantLanguage.kinyarwanda => 'rw-RW',
    DiscoverAssistantLanguage.kiswahili => 'sw-KE',
    DiscoverAssistantLanguage.french => 'fr-FR',
  };
}

@immutable
class DiscoverSuggestedPrompt {
  const DiscoverSuggestedPrompt({
    required this.label,
    required this.query,
  });

  final String label;
  final String query;
}

List<DiscoverSuggestedPrompt> discoverSuggestedPromptsFor(
  DiscoverAssistantLanguage language,
) {
  return switch (language) {
    DiscoverAssistantLanguage.kinyarwanda => const [
        DiscoverSuggestedPrompt(
          label: 'Shakisha abaguzi',
          query: 'Ndashaka kubona abaguzi b\'ibicuruzwa byanjye.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Abatanga muri Afurika y\'Iburasirazuba',
          query: 'Ndashaka abatanga ibikoresho muri Afurika y\'Iburasirazuba.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Ubucuruzi muri Kenya',
          query: 'Ndashaka kubona ubucuruzi muri Kenya.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Gukura ku masoko',
          query: 'Mfasha gukura ku masoko y\'akarere.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Ubufatanye',
          query: 'Ndashaka amahirwe y\'ubufatanye.',
        ),
      ],
    DiscoverAssistantLanguage.kiswahili => const [
        DiscoverSuggestedPrompt(
          label: 'Tafuta wanunuzi',
          query: 'Tafuta wanunuzi wa bidhaa zangu.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Wasambazaji Afrika Mashariki',
          query: 'Tafuta wasambazaji Afrika Mashariki.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Biashara nchini Kenya',
          query: 'Tafuta biashara nchini Kenya.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Panua masoko',
          query: 'Nisaidie kupanua katika masoko ya kikanda.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Ushirikiano',
          query: 'Tafuta fursa za ushirikiano.',
        ),
      ],
    DiscoverAssistantLanguage.french => const [
        DiscoverSuggestedPrompt(
          label: 'Trouver des acheteurs',
          query: 'Trouve des acheteurs pour mes produits.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Fournisseurs en Afrique de l’Est',
          query: 'Trouve des fournisseurs en Afrique de l’Est.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Entreprises au Kenya',
          query: 'Découvre des entreprises au Kenya.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Expansion régionale',
          query: 'Aide-moi à me développer sur les marchés régionaux.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Partenariats',
          query: 'Trouve des opportunités de partenariat.',
        ),
      ],
    DiscoverAssistantLanguage.english => const [
        DiscoverSuggestedPrompt(
          label: 'Find buyers',
          query: 'Find buyers for my products.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Find suppliers',
          query: 'Find suppliers in East Africa.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Businesses in Kenya',
          query: 'Discover businesses in Kenya.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Expand regionally',
          query: 'Help me expand into regional markets.',
        ),
        DiscoverSuggestedPrompt(
          label: 'Partnerships',
          query: 'Find partnership opportunities.',
        ),
      ],
  };
}

String discoverWelcomeGreeting({
  required DiscoverAssistantLanguage language,
  required String businessName,
}) {
  return switch (language) {
    DiscoverAssistantLanguage.kinyarwanda =>
      'Muraho, $businessName. Ndi umufasha wa TradeSquare AI. Mvugishe cyangwa wandike icyo ushaka — abaguzi, abatanga, ubucuruzi cyangwa amahirwe.',
    DiscoverAssistantLanguage.kiswahili =>
      'Habari, $businessName. Mimi ni msaidizi wa TradeSquare AI. Ongea au andika unachohitaji — wanunuzi, wasambazaji, biashara au fursa.',
    DiscoverAssistantLanguage.french =>
      'Bonjour, $businessName. Je suis l’assistant TradeSquare AI. Parlez ou écrivez ce dont vous avez besoin — acheteurs, fournisseurs, entreprises ou opportunités.',
    DiscoverAssistantLanguage.english =>
      'Hi, $businessName. I’m your TradeSquare AI assistant. Speak or type what you need — buyers, suppliers, businesses or opportunities.',
  };
}

String discoverWelcomeCapabilityNote(DiscoverAssistantLanguage language) {
  return switch (language) {
    DiscoverAssistantLanguage.kinyarwanda =>
      'Nshobora gushakisha amakuru ya TradeSquare, kugufungurira paji, no gutegura inyandiko mbere yo kuzitangaza.',
    DiscoverAssistantLanguage.kiswahili =>
      'Ninaweza kutafuta rekodi za TradeSquare, kufungua kurasa, na kuandaa rasimu kabla ya kuchapisha.',
    DiscoverAssistantLanguage.french =>
      'Je peux chercher dans TradeSquare, ouvrir des pages et préparer des brouillons avant publication.',
    DiscoverAssistantLanguage.english =>
      'I can search TradeSquare records, open pages, and prepare drafts before anything is published.',
  };
}

/// Maps a verified business card for assistant replies without inventing fields.
DiscoverChatMessage discoverAssistantMessageFromBusinesses({
  required String id,
  required String text,
  required DiscoverAssistantLanguage language,
  required List<TradeSquareDiscoverBusinessCard> businesses,
  List<TradeSquareDiscoverProductCard> products = const [],
  List<DiscoverAssistantAction> actions = const [],
  String? serviceNote,
  bool isStreaming = false,
}) {
  return DiscoverChatMessage(
    id: id,
    role: DiscoverChatRole.assistant,
    text: text,
    createdAt: DateTime.now().toUtc(),
    language: language,
    isStreaming: isStreaming,
    businesses: businesses,
    products: products,
    actions: actions,
    serviceNote: serviceNote,
  );
}

bool discoverBusinessIsApproved(TradeSquareMockBusiness business) {
  return business.verificationStatus ==
      TradeSquareMockVerificationStatus.approved;
}
