import '../../home/domain/trade_square_home_feed.dart';
import '../domain/discover_conversation_memory.dart';
import '../domain/trade_square_discover_assistant.dart';
import '../domain/trade_square_discover_models.dart';
import '../domain/trade_square_discover_search.dart';
import 'trade_square_mock_discover_repository.dart';

abstract class TradeSquareDiscoverAssistantService {
  Stream<DiscoverAssistantTurn> respond({
    required String message,
    required TradeSquareHomeProfile profile,
    String? localeHint,
    DiscoverConversationMemory? memory,
  });
}

class TradeSquareLocalDiscoverAssistantService
    implements TradeSquareDiscoverAssistantService {
  TradeSquareLocalDiscoverAssistantService({
    TradeSquareDiscoverSearchService? searchService,
    DiscoverLanguageDetector detector = const DiscoverLanguageDetector(),
    TradeSquareDiscoverQueryParser parser = const TradeSquareDiscoverQueryParser(),
  })  : _search = searchService ?? createTradeSquareDiscoverSearchService(),
        _detector = detector,
        _parser = parser;

  final TradeSquareDiscoverSearchService _search;
  final DiscoverLanguageDetector _detector;
  final TradeSquareDiscoverQueryParser _parser;

  @override
  Stream<DiscoverAssistantTurn> respond({
    required String message,
    required TradeSquareHomeProfile profile,
    String? localeHint,
    DiscoverConversationMemory? memory,
  }) async* {
    final session = memory ?? DiscoverConversationMemory();
    final language = _detector.detect(message, localeHint: localeHint);
    final effectiveMessage = session.mergeFollowUpQuery(message);
    final tool = _resolveTool(effectiveMessage, memory: session);
    session.recordUser(message, language);

    // Skip verbose "thinking" chatter for snappy navigation commands.
    final skipThinking = tool == DiscoverAssistantTool.openMessages ||
        tool == DiscoverAssistantTool.openBusinessProfile ||
        tool == DiscoverAssistantTool.openOpportunities ||
        tool == DiscoverAssistantTool.openHome;

    if (!skipThinking) {
      yield DiscoverAssistantTurn(
        userText: message,
        language: language,
        replyText: _thinkingCopy(language),
        tool: tool,
        serviceNote: _pipelineNote(),
      );
    }

    switch (tool) {
      case DiscoverAssistantTool.openMessages:
        yield _navigationTurn(
          message: message,
          language: language,
          tool: tool,
          target: 'messages',
          reply: _copy(
            language,
            en: 'Opening Messages.',
            rw: 'Ndagufungurira ubutumwa.',
            sw: 'Nafungua ujumbe.',
            fr: 'J’ouvre Messages.',
          ),
          memory: session,
        );
        return;
      case DiscoverAssistantTool.openBusinessProfile:
        yield _navigationTurn(
          message: message,
          language: language,
          tool: tool,
          target: 'business',
          reply: _copy(
            language,
            en: 'Opening your business profile.',
            rw: 'Ndagufungurira umwirondoro w’ubucuruzi bwawe.',
            sw: 'Nafungua wasifu wa biashara yako.',
            fr: 'J’ouvre le profil de votre entreprise.',
          ),
          memory: session,
        );
        return;
      case DiscoverAssistantTool.openOpportunities:
        yield _navigationTurn(
          message: message,
          language: language,
          tool: tool,
          target: 'opportunities',
          reply: _copy(
            language,
            en: 'Opening Opportunities.',
            rw: 'Ndagufungurira amahirwe.',
            sw: 'Nafungua fursa.',
            fr: 'J’ouvre les opportunités.',
          ),
          memory: session,
        );
        return;
      case DiscoverAssistantTool.openHome:
        yield _navigationTurn(
          message: message,
          language: language,
          tool: tool,
          target: 'home',
          reply: _copy(
            language,
            en: 'Taking you home.',
            rw: 'Ndagutwara ku rupapuro rw’ibanze.',
            sw: 'Nakupeleka nyumbani.',
            fr: 'Je vous ramène à l’accueil.',
          ),
          memory: session,
        );
        return;
      case DiscoverAssistantTool.draftBuyingRequest:
        final draft = _buyingRequestDraft(message, profile, language);
        yield DiscoverAssistantTurn(
          userText: message,
          language: language,
          replyText: _copy(
            language,
            en:
                'Here is a draft buying request. Review and edit it before publishing — nothing has been submitted.',
            rw:
                'Dore inyandiko y’icyifuzo cyo kugura. Reba kandi uhindure mbere yo gutangaza — nta cyo cyoherejwe.',
            sw:
                'Hii ni rasimu ya ombi la ununuzi. Kagua kabla ya kuchapisha — hakuna kilichotumwa.',
            fr:
                'Voici un brouillon de demande d’achat. Relisez-le avant publication — rien n’a été envoyé.',
          ),
          tool: tool,
          draftContent: draft,
          actions: [
            DiscoverAssistantAction(
              tool: DiscoverAssistantTool.draftBuyingRequest,
              label: _copy(
                language,
                en: 'Review draft',
                rw: 'Reba inyandiko',
                sw: 'Kagua rasimu',
                fr: 'Voir le brouillon',
              ),
              payload: {'draft': draft},
              requiresConfirmation: true,
            ),
          ],
          serviceNote: _pipelineNote(),
        );
        return;
      case DiscoverAssistantTool.improveBusinessDescription:
        final draft = _descriptionDraft(profile, language);
        yield DiscoverAssistantTurn(
          userText: message,
          language: language,
          replyText: _copy(
            language,
            en:
                'Suggested profile copy based on your current business details. Edit before applying.',
            rw:
                'Inyandiko isabwa hashingiwe ku makuru y’ubucuruzi bwawe. Hindura mbere yo kuyikoresha.',
            sw:
                'Pendekezo la wasifu kulingana na maelezo yako ya biashara. Hariri kabla ya kutumia.',
            fr:
                'Suggestion de texte basée sur votre profil actuel. Modifiez avant d’appliquer.',
          ),
          tool: tool,
          draftContent: draft,
          actions: [
            DiscoverAssistantAction(
              tool: DiscoverAssistantTool.improveBusinessDescription,
              label: _copy(
                language,
                en: 'Review description',
                rw: 'Reba ibisobanuro',
                sw: 'Kagua maelezo',
                fr: 'Voir la description',
              ),
              payload: {'draft': draft},
              requiresConfirmation: true,
            ),
            const DiscoverAssistantAction(
              tool: DiscoverAssistantTool.openBusinessProfile,
              label: 'Open My Business',
            ),
          ],
          serviceNote: _pipelineNote(),
        );
        return;
      case DiscoverAssistantTool.translateText:
        yield DiscoverAssistantTurn(
          userText: message,
          language: language,
          replyText: _translateHelp(language, profile),
          tool: tool,
          serviceNote:
              'Dedicated AIMBAZA / multilingual MT is not connected. Showing a local profile summary only.',
        );
        return;
      case DiscoverAssistantTool.searchOpportunities:
      case DiscoverAssistantTool.searchBusinesses:
      case DiscoverAssistantTool.none:
        break;
    }

    final criteria = _parser.parse(effectiveMessage);
    await for (final stage in _search.searchJourney(
      query: effectiveMessage,
      profile: profile,
      category: criteria.category,
    )) {
      if (stage.stage == TradeSquareDiscoverSearchStage.understanding ||
          stage.stage == TradeSquareDiscoverSearchStage.identifying ||
          stage.stage == TradeSquareDiscoverSearchStage.searching ||
          stage.stage == TradeSquareDiscoverSearchStage.ranking) {
        // Keep UI state updates, but avoid chatty intermediate spoken lines.
        yield DiscoverAssistantTurn(
          userText: message,
          language: language,
          replyText: _progressCopy(language, stage.stage),
          tool: DiscoverAssistantTool.searchBusinesses,
          criteria: stage.criteria,
          serviceNote: stage.serviceNote ?? _pipelineNote(),
        );
        continue;
      }

      final empty = stage.isEmpty;
      final reply = empty
          ? _emptyCopy(language, stage.criteria)
          : _resultsCopy(language, stage);
      session.recordAssistant(
        text: reply,
        tool: DiscoverAssistantTool.searchBusinesses,
        criteria: stage.criteria,
      );
      yield DiscoverAssistantTurn(
        userText: message,
        language: language,
        replyText: reply,
        tool: DiscoverAssistantTool.searchBusinesses,
        criteria: stage.criteria,
        businesses: stage.businesses,
        products: stage.products,
        actions: [
          if (!empty)
            DiscoverAssistantAction(
              tool: DiscoverAssistantTool.searchBusinesses,
              label: _copy(
                language,
                en: 'Refine search',
                rw: 'Ongera ushakishe',
                sw: 'Boresha utafutaji',
                fr: 'Affiner la recherche',
              ),
            ),
          const DiscoverAssistantAction(
            tool: DiscoverAssistantTool.openMessages,
            label: 'Open Messages',
          ),
        ],
        serviceNote: stage.serviceNote ?? _pipelineNote(),
      );
    }
  }

  DiscoverAssistantTool _resolveTool(
    String raw, {
    DiscoverConversationMemory? memory,
  }) {
    final lower = raw.toLowerCase();
    if (memory?.looksLikeFollowUp(raw) == true &&
        memory?.lastTool != null &&
        !_hasAny(lower, [
          'open',
          'messages',
          'home',
          'profile',
          'opportunity',
          'amahirwe',
          'fursa',
        ])) {
      return memory!.lastTool!;
    }
    if (_hasAny(lower, [
      'open my messages',
      'take me to my messages',
      'go to messages',
      'ubutumwa',
      'messages',
      'ujumbe',
      'ouvrir messages',
    ])) {
      return DiscoverAssistantTool.openMessages;
    }
    if (_hasAny(lower, [
      'open my business',
      'business profile',
      'my business',
      'umwirondoro',
      'wasifu wa biashara',
      'profil de mon entreprise',
      'mon entreprise',
    ])) {
      return DiscoverAssistantTool.openBusinessProfile;
    }
    if (_hasAny(lower, [
      'published opportunities',
      'my opportunities',
      'show opportunities',
      'amahirwe yanjye',
      'fursa zangu',
      'mes opportunités',
    ])) {
      return DiscoverAssistantTool.openOpportunities;
    }
    if (_hasAny(lower, [
      'take me home',
      'go home',
      'open home',
      'accueil',
      'nyumbani',
    ])) {
      return DiscoverAssistantTool.openHome;
    }
    if (_hasAny(lower, [
      'create a buying request',
      'draft buying',
      'icyifuzo cyo kugura',
      'ombi la ununuzi',
      'demande d’achat',
      'demande d\'achat',
    ])) {
      return DiscoverAssistantTool.draftBuyingRequest;
    }
    if (_hasAny(lower, [
      'improve my business description',
      'improve my description',
      'kunozera ibisobanuro',
      'boresha maelezo',
      'améliorer ma description',
    ])) {
      return DiscoverAssistantTool.improveBusinessDescription;
    }
    if (_hasAny(lower, [
      'translate',
      'sobanura',
      'tafsiri',
      'traduire',
      'kiswahili',
    ])) {
      return DiscoverAssistantTool.translateText;
    }
    if (_hasAny(lower, [
      'partnership',
      'ubufatanye',
      'ushirikiano',
      'partenariat',
      'buying request',
      'opportunity',
      'amahirwe',
      'fursa',
      'opportunité',
    ])) {
      return DiscoverAssistantTool.searchOpportunities;
    }
    return DiscoverAssistantTool.searchBusinesses;
  }

  DiscoverAssistantTurn _navigationTurn({
    required String message,
    required DiscoverAssistantLanguage language,
    required DiscoverAssistantTool tool,
    required String target,
    required String reply,
    DiscoverConversationMemory? memory,
  }) {
    memory?.recordAssistant(text: reply, tool: tool);
    return DiscoverAssistantTurn(
      userText: message,
      language: language,
      replyText: reply,
      tool: tool,
      navigationTarget: target,
      actions: [
        DiscoverAssistantAction(
          tool: tool,
          label: reply,
        ),
      ],
      serviceNote: _pipelineNote(),
    );
  }

  String _buyingRequestDraft(
    String message,
    TradeSquareHomeProfile profile,
    DiscoverAssistantLanguage language,
  ) {
    final need = profile.productsNeeded.isNotEmpty
        ? profile.productsNeeded.first
        : 'regional supply partners';
    final markets = profile.targetMarkets.take(2).join(' and ');
    return _copy(
      language,
      en:
          'Buying request: Looking for $need for ${profile.businessName ?? 'our business'}'
          '${markets.isEmpty ? '' : ' serving $markets'}. Context: $message',
      rw:
          'Icyifuzo cyo kugura: Turashaka $need kuri ${profile.businessName ?? 'ubucuruzi bwacu'}'
          '${markets.isEmpty ? '' : ' dukorera $markets'}. Inyandiko: $message',
      sw:
          'Ombi la ununuzi: Tunatafuta $need kwa ${profile.businessName ?? 'biashara yetu'}'
          '${markets.isEmpty ? '' : ' zinazohudumia $markets'}. Muktadha: $message',
      fr:
          'Demande d’achat : Nous recherchons $need pour ${profile.businessName ?? 'notre entreprise'}'
          '${markets.isEmpty ? '' : ' desservant $markets'}. Contexte : $message',
    );
  }

  String _descriptionDraft(
    TradeSquareHomeProfile profile,
    DiscoverAssistantLanguage language,
  ) {
    final name = profile.businessName ?? profile.displayName;
    final industry = profile.industry ?? 'trade';
    final location = profile.location ?? 'East Africa';
    final offers = profile.productsOffered.take(3).join(', ');
    return _copy(
      language,
      en:
          '$name is a $industry business based in $location. We focus on $offers and connect with partners across the region.',
      rw:
          '$name ni ubucuruzi bwo mu $industry buturuka $location. Dushishikajwe na $offers kandi dukorana n’abafatanyabikorwa bo mu karere.',
      sw:
          '$name ni biashara ya $industry iliyoko $location. Tunazingatia $offers na kushirikiana na washirika wa kikanda.',
      fr:
          '$name est une entreprise de $industry basée à $location. Nous nous concentrons sur $offers et collaborons avec des partenaires régionaux.',
    );
  }

  String _translateHelp(
    DiscoverAssistantLanguage language,
    TradeSquareHomeProfile profile,
  ) {
    final draft = _descriptionDraft(profile, DiscoverAssistantLanguage.kiswahili);
    return _copy(
      language,
      en:
          'Full machine translation is not connected yet. Here is a Kiswahili-oriented profile draft you can edit:\n\n$draft',
      rw:
          'Ubuhinduzi bwuzuye ntibuhujwe. Dore inyandiko y’umwirondoro mu Kiswahili ushobora guhindura:\n\n$draft',
      sw:
          'Tafsiri kamili haijaunganishwa bado. Hii ni rasimu ya wasifu kwa Kiswahili unaweza kuhariri:\n\n$draft',
      fr:
          'La traduction automatique n’est pas encore connectée. Voici un brouillon de profil orienté kiswahili à modifier :\n\n$draft',
    );
  }

  String _resultsCopy(
    DiscoverAssistantLanguage language,
    TradeSquareDiscoverSearchResult stage,
  ) {
    final businessCount = stage.businesses.length;
    final top = stage.businesses.isNotEmpty ? stage.businesses.first : null;
    final market = stage.criteria.targetMarkets.isNotEmpty
        ? stage.criteria.targetMarkets.first
        : (stage.criteria.originMarket ?? 'East Africa');
    final reason = top != null && top.reasons.isNotEmpty
        ? top.reasons.first
        : null;
    final topName = top?.business.name;

    if (businessCount == 1 && topName != null) {
      return _copy(
        language,
        en: reason == null
            ? 'I found $topName in $market.'
            : 'I found $topName in $market. $reason',
        rw: reason == null
            ? 'Nabonye $topName muri $market.'
            : 'Nabonye $topName muri $market. $reason',
        sw: reason == null
            ? 'Nimepata $topName katika $market.'
            : 'Nimepata $topName katika $market. $reason',
        fr: reason == null
            ? 'J’ai trouvé $topName à $market.'
            : 'J’ai trouvé $topName à $market. $reason',
      );
    }

    return _copy(
      language,
      en: topName == null
          ? 'I found $businessCount matching businesses around $market.'
          : 'I found $businessCount matches around $market. Top result: $topName'
              '${reason == null ? '.' : '. $reason'}',
      rw: topName == null
          ? 'Nabonye ubucuruzi $businessCount hafi ya $market.'
          : 'Nabonye ubucuruzi $businessCount hafi ya $market. Icyambere: $topName'
              '${reason == null ? '.' : '. $reason'}',
      sw: topName == null
          ? 'Nimepata biashara $businessCount karibu na $market.'
          : 'Nimepata biashara $businessCount karibu na $market. Ya juu: $topName'
              '${reason == null ? '.' : '. $reason'}',
      fr: topName == null
          ? 'J’ai trouvé $businessCount entreprises autour de $market.'
          : 'J’ai trouvé $businessCount résultats autour de $market. Principal : $topName'
              '${reason == null ? '.' : '. $reason'}',
    );
  }

  String _emptyCopy(
    DiscoverAssistantLanguage language,
    TradeSquareDiscoverCriteria criteria,
  ) {
    return _copy(
      language,
      en:
          'No matching TradeSquare records yet for “${criteria.rawQuery}”. Try a broader market or a shorter product description.',
      rw:
          'Nta makuru ya TradeSquare yahuye na “${criteria.rawQuery}”. Gerageza isoko rinini cyangwa ibisobanuro bigufi.',
      sw:
          'Hakuna rekodi za TradeSquare zinazolingana na “${criteria.rawQuery}”. Panua soko au fupisha maelezo.',
      fr:
          'Aucun enregistrement TradeSquare pour « ${criteria.rawQuery} ». Élargissez le marché ou raccourcissez la description.',
    );
  }

  String _progressCopy(
    DiscoverAssistantLanguage language,
    TradeSquareDiscoverSearchStage stage,
  ) {
    return switch (stage) {
      TradeSquareDiscoverSearchStage.understanding => _copy(
          language,
          en: 'Understanding your request…',
          rw: 'Ndagushaka icyo ushaka…',
          sw: 'Ninaelewa ombi lako…',
          fr: 'Je comprends votre demande…',
        ),
      TradeSquareDiscoverSearchStage.identifying => _copy(
          language,
          en: 'Identifying products, markets and intent…',
          rw: 'Ndagena ibicuruzwa, amasoko n’intego…',
          sw: 'Natambua bidhaa, masoko na lengo…',
          fr: 'J’identifie produits, marchés et intention…',
        ),
      TradeSquareDiscoverSearchStage.searching => _copy(
          language,
          en: 'Searching TradeSquare records…',
          rw: 'Ndashakisha mu makuru ya TradeSquare…',
          sw: 'Natafuta katika rekodi za TradeSquare…',
          fr: 'Je cherche dans TradeSquare…',
        ),
      TradeSquareDiscoverSearchStage.ranking => _copy(
          language,
          en: 'Organizing the most relevant matches…',
          rw: 'Nategura ibihuye cyane…',
          sw: 'Napanga yanayofaa zaidi…',
          fr: 'J’organise les correspondances pertinentes…',
        ),
      _ => _thinkingCopy(language),
    };
  }

  String _thinkingCopy(DiscoverAssistantLanguage language) {
    return _copy(
      language,
      en: 'Thinking…',
      rw: 'Ndatekereza…',
      sw: 'Nafikiri…',
      fr: 'Réflexion…',
    );
  }

  String _pipelineNote() {
    return 'TradeSquare assistant uses catalog matching, session follow-up memory and '
        'local language routing. LiveKit Agents, NVIDIA Kinyarwanda STT and dedicated '
        'Kinyarwanda TTS remain optional adapters until credentials and model workers exist.';
  }

  String _copy(
    DiscoverAssistantLanguage language, {
    required String en,
    required String rw,
    required String sw,
    required String fr,
  }) {
    return switch (language) {
      DiscoverAssistantLanguage.kinyarwanda => rw,
      DiscoverAssistantLanguage.kiswahili => sw,
      DiscoverAssistantLanguage.french => fr,
      DiscoverAssistantLanguage.english => en,
    };
  }

  bool _hasAny(String lower, List<String> needles) {
    for (final needle in needles) {
      if (lower.contains(needle.toLowerCase())) return true;
    }
    return false;
  }
}
