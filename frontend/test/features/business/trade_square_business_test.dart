import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/features/authentication/domain/trade_square_auth_models.dart';
import 'package:tradesquare/features/business/data/trade_square_mock_business_repository.dart';
import 'package:tradesquare/features/business/domain/trade_square_business_workspace.dart';
import 'package:tradesquare/features/business/presentation/trade_square_business_page.dart';
import 'package:tradesquare/features/home/domain/trade_square_home_feed.dart';

import '../../fixtures/catalog_test_fixture.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: TradeSquareLocalizations.delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

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

  test('mock repository loads workspace with real listing metrics', () async {
    final repository = TradeSquareMockBusinessRepository(
      simulateNetworkDelay: false,
    );
    final workspace = await repository.loadWorkspace(
      role: TradeSquareAccountRole.both,
      profile: profile,
    );

    expect(workspace.business.name, 'AgriHub Rwanda');
    expect(workspace.isVerified, isTrue);
    expect(workspace.products, isNotEmpty);
    expect(workspace.opportunities, isNotEmpty);
    expect(workspace.activity, isNotEmpty);
    expect(
      workspace.activity.any((item) => item.label == 'Product views'),
      isTrue,
    );
    expect(workspace.aiSuggestions, isNotEmpty);
  });

  test('cover helper returns industry-specific imagery', () {
    expect(
      tradeSquareBusinessCoverForIndustry('Agriculture'),
      contains('unsplash.com'),
    );
  });

  testWidgets('business page renders header, tabs and overview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        TradeSquareBusinessPage(
          role: TradeSquareAccountRole.both,
          profile: profile,
          repository: TradeSquareMockBusinessRepository(
            simulateNetworkDelay: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AgriHub Rwanda'), findsWidgets);
    expect(find.text('Edit business'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Products & Services'), findsOneWidget);
    expect(find.text('Opportunities'), findsOneWidget);
    expect(find.text('Business Activity'), findsOneWidget);
    expect(find.text('About the business'), findsOneWidget);
    expect(find.text('TradeSquare Business AI'), findsOneWidget);
  });

  testWidgets('preview shows public profile and can exit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        TradeSquareBusinessPage(
          role: TradeSquareAccountRole.both,
          profile: profile,
          repository: TradeSquareMockBusinessRepository(
            simulateNetworkDelay: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Public preview'), findsOneWidget);
    expect(find.text('Exit preview'), findsOneWidget);

    await tester.tap(find.text('Exit preview'));
    await tester.pumpAndSettle();

    expect(find.text('Edit business'), findsOneWidget);
  });

  testWidgets('desktop layout keeps tabs and product management',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        TradeSquareBusinessPage(
          role: TradeSquareAccountRole.both,
          profile: profile,
          repository: TradeSquareMockBusinessRepository(
            simulateNetworkDelay: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Products & Services'));
    await tester.pumpAndSettle();

    expect(find.text('Add product'), findsOneWidget);
    expect(find.textContaining('Premium rice'), findsWidgets);
  });
}
