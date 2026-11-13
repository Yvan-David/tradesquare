import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/features/home/domain/trade_square_home_feed.dart';
import 'package:tradesquare/features/home/presentation/trade_square_home_page.dart';

const _profile = TradeSquareHomeProfile(
  displayName: 'Account name',
  industry: 'Agriculture',
  interests: ['Packaging'],
);

const _opportunity = TradeSquareFeedOpportunity(
  id: 'resource-1',
  type: TradeSquareOpportunityType.productListing,
  title: 'Opportunity title',
  summary: 'Opportunity summary',
  category: 'Packaging',
  recommendationReasons: [TradeSquareRecommendationReason.productMatch],
);

void main() {
  const widths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0, 1440.0];
  for (final width in widths) {
    testWidgets('lays out the Home feed without overflow at $width pixels',
        (tester) async {
      await _setViewport(tester, width);
      await tester.pumpWidget(_app(
        const TradeSquareHomePage(
          profile: _profile,
          sections: [
            TradeSquareFeedSection(
              type: TradeSquareFeedSectionType.opportunities,
              opportunities: [_opportunity],
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      await _revealFeed(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Opportunity title', skipOffstage: false),
        findsOneWidget,
      );
    });
  }

  testWidgets('shows an honest empty state when no feed data is provided',
      (tester) async {
    await _setViewport(tester, 390);
    await tester.pumpWidget(
      _app(const TradeSquareHomePage(profile: TradeSquareHomeProfile())),
    );
    await tester.pumpAndSettle();
    await _revealFeed(tester);

    expect(
      find.text('Your discovery feed is getting ready', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Opportunity title', skipOffstage: false), findsNothing);
  });

  testWidgets('opens interest editor and saves selected interests',
      (tester) async {
    await _setViewport(tester, 390);
    List<String>? updatedInterests;
    await tester.pumpWidget(
      _app(
        TradeSquareHomePage(
          profile: _profile,
          interestOptions: const ['Packaging', 'Logistics'],
          onInterestsChanged: (interests) => updatedInterests = interests,
        ),
      ),
    );

    await tester.tap(find.text('Manage interests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logistics'));
    await tester.tap(find.text('Save interests'));
    await tester.pumpAndSettle();

    expect(updatedInterests, containsAll(['Packaging', 'Logistics']));
  });

  testWidgets('recommendation feedback and explanation are host driven',
      (tester) async {
    await _setViewport(tester, 390);
    TradeSquareRecommendationFeedback? feedback;
    TradeSquareFeedOpportunity? explained;
    await tester.pumpWidget(
      _app(
        TradeSquareHomePage(
          profile: _profile,
          sections: const [
            TradeSquareFeedSection(
              type: TradeSquareFeedSectionType.products,
              opportunities: [_opportunity],
            ),
          ],
          onRecommendationFeedback: (opportunity, value) => feedback = value,
          onWhySeeing: (opportunity) => explained = opportunity,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _revealFeed(tester);

    await tester.tap(find.text('Show me more like this', skipOffstage: false));
    expect(feedback, TradeSquareRecommendationFeedback.moreLikeThis);

    await tester.tap(find.text('Why am I seeing this?', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(explained?.id, _opportunity.id);
    expect(find.text('Relates to a product or service you offer or need'),
        findsOneWidget);
  });

  testWidgets('long localized feedback actions wrap on narrow screens',
      (tester) async {
    await _setViewport(tester, 360);
    await tester.pumpWidget(
      _app(
        TradeSquareHomePage(
          profile: _profile,
          sections: const [
            TradeSquareFeedSection(
              type: TradeSquareFeedSectionType.products,
              opportunities: [_opportunity],
            ),
          ],
          onRecommendationFeedback: (opportunity, feedback) {},
          onWhySeeing: (opportunity) {},
        ),
        locale: const Locale('fr'),
      ),
    );
    await tester.pumpAndSettle();
    await _revealFeed(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('Cela ne m’intéresse pas', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Pourquoi cette suggestion ?', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('renders localized headings across all supported locales',
      (tester) async {
    const expectedTitles = {
      'en': 'Buyers looking for your products',
      'rw': 'Abaguzi bashaka ibyo ugurisha',
      'sw': 'Wanunuzi wanaotafuta bidhaa zako',
      'fr': 'Acheteurs recherchant vos produits',
    };
    for (final languageCode in expectedTitles.keys) {
      final locale = Locale(languageCode);
      await _setViewport(tester, 430);
      await tester.pumpWidget(
        _app(
          const TradeSquareHomePage(
            profile: _profile,
            sections: [
              TradeSquareFeedSection(
                type: TradeSquareFeedSectionType.buyers,
                opportunities: [],
              ),
            ],
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await _revealFeed(tester);
      expect(tester.takeException(), isNull, reason: locale.languageCode);
      expect(
        find.text(expectedTitles[languageCode]!, skipOffstage: false),
        findsOneWidget,
      );
    }
  });

  testWidgets('AI question is submitted to the host without a fake response',
      (tester) async {
    await _setViewport(tester, 1280);
    String? question;
    await tester.pumpWidget(
      _app(
        TradeSquareHomePage(
          profile: _profile,
          onAskAssistant: (value) => question = value,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('home-ai-question')),
      'Find packaging suppliers',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);

    expect(question, 'Find packaging suppliers');
  });
}

Widget _app(
  TradeSquareHomePage page, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    theme: AppTheme.light,
    localizationsDelegates: TradeSquareLocalizations.delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ColoredBox(
        color: const Color(0xFFF3F6F8),
        child: page,
      ),
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _revealFeed(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  await tester.drag(scrollable.first, const Offset(0, -700));
  await tester.pumpAndSettle();
}
