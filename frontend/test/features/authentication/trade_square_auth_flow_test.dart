import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/app.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/features/authentication/data/trade_square_auth_repository.dart';
import 'package:tradesquare/features/authentication/domain/trade_square_auth_models.dart';
import 'package:tradesquare/features/authentication/presentation/trade_square_auth_flow.dart';
import 'package:tradesquare/shared/components/trade_square_footer.dart';
import 'package:tradesquare/shared/components/trade_square_navigation_shell.dart';
import 'package:tradesquare/shared/components/trade_square_sidebar.dart';
import 'package:tradesquare/shared/components/trade_square_top_bar.dart';

import '../../fixtures/catalog_test_fixture.dart';

void main() {
  setUpAll(loadCatalogTestFixture);

  const widths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1440.0];

  for (final width in widths) {
    testWidgets('login screen fits at $width pixels', (tester) async {
      await _setViewport(tester, width);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(DropdownButtonFormField<TradeSquareAccountRole>),
          findsNothing);
    });
  }

  testWidgets('login form provides inline validation', (tester) async {
    await _setViewport(tester, 390);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'passphrase');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('sign in opens role-personalized home from account role',
      (tester) async {
    const roleLabels = {
      TradeSquareAccountRole.buyer: 'Buyer',
      TradeSquareAccountRole.supplier: 'Supplier',
      TradeSquareAccountRole.both: 'Buyer and supplier',
    };

    for (final role in TradeSquareAccountRole.values) {
      await _setViewport(tester, 390);
      await tester.pumpWidget(
        TradeSquareApp(
          key: ValueKey('auth-role-$role'),
          authRepository: FakeTradeSquareAuthRepository(defaultRole: role),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'alex@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'passphrase');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsNothing);
      expect(find.byType(DropdownButtonFormField<TradeSquareAccountRole>),
          findsNothing);
      expect(find.byType(TradeSquareNavigationShell), findsOneWidget);
      expect(find.byType(TradeSquareTopBar), findsOneWidget);
      expect(find.byType(TradeSquareFooter), findsOneWidget);

      await tester.tap(find.byTooltip('alex@example.com, ${roleLabels[role]}'));
      await tester.pumpAndSettle();
      expect(find.text(roleLabels[role]!), findsWidgets);
      expect(find.text('alex@example.com'), findsWidgets);

      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    }
  });


  testWidgets('signed-in desktop home uses the shared sidebar and top bar',
      (tester) async {
    await _setViewport(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'passphrase');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.byType(TradeSquareTopBar), findsOneWidget);
    expect(find.byType(TradeSquareFooter), findsOneWidget);
    expect(find.byType(TradeSquareSidebar), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(TradeSquareSidebar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(
        find.text('© 2026 TradeSquare. All rights reserved.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration links to login and validates confirmation',
      (tester) async {
    await _setViewport(tester, 430);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your TradeSquare account'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Example');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'alex@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '5550100');
    await tester.enterText(find.byType(TextFormField).at(3), 'StrongPass!1');
    await tester.enterText(find.byType(TextFormField).at(4), 'DifferentPass!1');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Continue').last);
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.text('Tell us about your business'), findsNothing);
  });

  testWidgets('four locales expose localized login experiences',
      (tester) async {
    const expectedTitles = {
      'en': 'Welcome back',
      'rw': 'Murakaza neza nanone',
      'sw': 'Karibu tena',
      'fr': 'Bon retour',
    };
    for (final entry in expectedTitles.entries) {
      await _setViewport(tester, 430);
      await tester.pumpWidget(
        _localizedApp(Locale(entry.key)),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });

  testWidgets('registration continues into business onboarding', (tester) async {
    await _setViewport(tester, 390);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Example');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'alex@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '5550100');
    await tester.enterText(find.byType(TextFormField).at(3), 'StrongPass!1');
    await tester.enterText(find.byType(TextFormField).at(4), 'StrongPass!1');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Continue').last);
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'eligibility screen');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rwanda').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Example Trading');
    await tester.tap(
      find.byType(DropdownButtonFormField<TradeSquareBusinessType>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limited company').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<TradeSquareRegistrationStatus>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registered').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'REG-123');
    await tester.enterText(find.byType(TextFormField).at(2), 'Kigali');
    await tester.ensureVisible(find.text('Continue').last);
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'certificate screen');
    expect(find.text('Verify your business identity'), findsOneWidget);
    expect(
      find.textContaining('reviewed before marketplace access'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Continue without a document'));
    await tester.tap(find.text('Continue without a document'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'onboarding start');

    for (var step = 0; step < 6; step++) {
      if (step == 0) {
        expect(find.text('Business information'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Continue').last);
      await tester.tap(find.text('Continue').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'onboarding step $step');
    }
    expect(find.text('Review your information'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Application status'), findsOneWidget);
    expect(find.text('Certificate not submitted'), findsWidgets);
    expect(
      find.textContaining('We will email you when your review status changes'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app([TradeSquareAuthRepository? auth]) {
  return TradeSquareApp(
    authRepository: auth ?? FakeTradeSquareAuthRepository(),
  );
}

Widget _localizedApp(Locale locale) {
  return MaterialApp(
    locale: locale,
    theme: AppTheme.light,
    localizationsDelegates: TradeSquareLocalizations.delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TradeSquareAuthFlow(
      authRepository: FakeTradeSquareAuthRepository(),
      onLocaleChanged: (_) {},
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
