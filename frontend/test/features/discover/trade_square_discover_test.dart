import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/features/discover/data/trade_square_discover_assistant_service.dart';
import 'package:tradesquare/features/discover/data/trade_square_mock_discover_repository.dart';
import 'package:tradesquare/features/discover/domain/discover_conversation_memory.dart';
import 'package:tradesquare/features/discover/domain/discover_speech_naturalness.dart';
import 'package:tradesquare/features/discover/domain/trade_square_discover_assistant.dart';
import 'package:tradesquare/features/discover/domain/trade_square_discover_models.dart';
import 'package:tradesquare/features/discover/domain/trade_square_discover_search.dart';
import 'package:tradesquare/features/discover/presentation/trade_square_discover_page.dart';
import 'package:tradesquare/features/discover/presentation/widgets/discover_voice_orb.dart';
import 'package:tradesquare/features/home/domain/trade_square_home_feed.dart';

import '../../fixtures/catalog_test_fixture.dart';

void main() {
  setUpAll(loadCatalogTestFixture);

  const profile = TradeSquareHomeProfile(
    displayName: 'AgriHub Rwanda',
    businessName: 'AgriHub Rwanda',
    industry: 'Agriculture',
    category: 'Food production',
    location: 'Kigali',
    targetMarkets: ['Kenya', 'Uganda'],
    interests: ['Packaging', 'Logistics'],
    productsOffered: ['Rice', 'Beans'],
    productsNeeded: ['Packaging materials'],
    intent: TradeSquareBusinessIntent.both,
  );

  test('parser extracts product, origin and target market', () {
    const parser = TradeSquareDiscoverQueryParser();
    final criteria = parser.parse(
      'I manufacture school furniture in Rwanda and want to sell in Uganda.',
    );

    expect(criteria.originMarket, 'Rwanda');
    expect(criteria.targetMarkets, contains('Uganda'));
    expect(
      criteria.products.any(
        (product) => product.toLowerCase().contains('furniture'),
      ),
      isTrue,
    );
    expect(criteria.industry, 'Manufacturing');
  });

  test('parser understands Kinyarwanda maize buyers in Kenya', () {
    const parser = TradeSquareDiscoverQueryParser();
    final criteria = parser.parse(
      "Ndashaka kubona abaguzi b'ibigori muri Kenya.",
    );

    expect(criteria.activity, 'Find buyers');
    expect(criteria.products, contains('Maize'));
    expect(criteria.targetMarkets, contains('Kenya'));
  });

  test('language detector recognizes Kinyarwanda', () {
    const detector = DiscoverLanguageDetector();
    expect(
      detector.detect("Ndashaka kubona abaguzi muri Kenya."),
      DiscoverAssistantLanguage.kinyarwanda,
    );
  });

  test('mock repository returns evidence-backed matches without percentages',
      () async {
    final repository = TradeSquareMockDiscoverRepository(
      simulateNetworkDelay: false,
    );
    final stages = await repository
        .searchJourney(
          query:
              'I manufacture school furniture in Rwanda and want to sell in Uganda.',
          profile: profile,
        )
        .toList();

    expect(stages.first.stage, TradeSquareDiscoverSearchStage.understanding);
    expect(stages.last.stage, TradeSquareDiscoverSearchStage.ready);
    expect(stages.last.businesses, isNotEmpty);
    expect(stages.last.serviceNote, isNotNull);
    for (final card in stages.last.businesses) {
      expect(card.reasons, isNotEmpty);
      for (final reason in card.reasons) {
        expect(reason.contains('%'), isFalse);
      }
    }
  });

  test('assistant returns progressive catalog results for English search',
      () async {
    final assistant = TradeSquareLocalDiscoverAssistantService(
      searchService: TradeSquareMockDiscoverRepository(
        simulateNetworkDelay: false,
      ),
    );
    final turns = await assistant
        .respond(
          message: 'Find packaging material suppliers in Rwanda.',
          profile: profile,
        )
        .toList();

    expect(turns.last.businesses, isNotEmpty);
    expect(turns.last.language, DiscoverAssistantLanguage.english);
    expect(turns.last.serviceNote, isNotNull);
  });

  test('speech naturalness strips markdown and keeps concise speech', () {
    const helper = DiscoverSpeechNaturalness();
    final spoken = helper.conciseSpokenReply(
      '## Hello\nI found **AgriHub**. ```code``` More detail later.',
    );
    expect(spoken.contains('```'), isFalse);
    expect(spoken.contains('**'), isFalse);
    expect(spoken.toLowerCase(), contains('agrihub'));
  });

  test('conversation memory merges follow-up market refinements', () {
    final memory = DiscoverConversationMemory()
      ..recordUser(
        'Find packaging suppliers in Rwanda.',
        DiscoverAssistantLanguage.english,
      )
      ..recordAssistant(
        text: 'Found matches',
        tool: DiscoverAssistantTool.searchBusinesses,
        criteria: const TradeSquareDiscoverCriteria(
          rawQuery: 'Find packaging suppliers in Rwanda.',
          products: ['Packaging'],
          targetMarkets: ['Rwanda'],
          activity: 'Find suppliers',
        ),
      );

    final merged = memory.mergeFollowUpQuery('What about Kenya?');
    expect(merged.toLowerCase(), contains('kenya'));
    expect(memory.looksLikeFollowUp('What about Kenya?'), isTrue);
  });

  testWidgets('discover networking page has no voice UI and shows sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: TradeSquareLocalizations.delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TradeSquareDiscoverPage(
            profile: profile,
            locale: const Locale('en'),
            onLocaleChanged: (_) {},
            searchService: TradeSquareMockDiscoverRepository(
              simulateNetworkDelay: false,
            ),
            assistantService: TradeSquareLocalDiscoverAssistantService(
              searchService: TradeSquareMockDiscoverRepository(
                simulateNetworkDelay: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Businesses you may want to know'), findsOneWidget);
    expect(find.text('Recommended businesses'), findsOneWidget);
    expect(find.text('Commercial opportunities'), findsOneWidget);
    expect(
      find.text('Ask TradeSquare AI to find business connections…'),
      findsOneWidget,
    );
    expect(find.byType(DiscoverVoiceOrb), findsNothing);
    expect(find.text('Start voice'), findsNothing);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('text AI entry opens chat sheet without microphone controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: TradeSquareLocalizations.delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TradeSquareDiscoverPage(
            profile: profile,
            locale: const Locale('en'),
            onLocaleChanged: (_) {},
            searchService: TradeSquareMockDiscoverRepository(
              simulateNetworkDelay: false,
            ),
            assistantService: TradeSquareLocalDiscoverAssistantService(
              searchService: TradeSquareMockDiscoverRepository(
                simulateNetworkDelay: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.text('Ask TradeSquare AI to find business connections…').first,
    );
    await tester.pumpAndSettle();

    expect(find.text('TradeSquare AI'), findsWidgets);
    expect(find.text('Text assistant for business discovery'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.byType(DiscoverVoiceOrb), findsNothing);
  });
}
