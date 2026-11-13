import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/shared/components/trade_square_top_bar.dart';
import 'package:tradesquare/shared/navigation/trade_square_destination.dart';

void main() {
  const widths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0, 1440.0];
  const account = TradeSquareAccount(
    name: 'Amahle Niyonzima',
    businessName: 'East Africa Trading',
    initials: 'AN',
  );

  for (final width in widths) {
    testWidgets('fits top bar at $width logical pixels', (tester) async {
      await _setViewport(tester, width);
      await tester.pumpWidget(_app(const TradeSquareTopBar(
        locale: Locale('en'),
        onLocaleChanged: _ignoreLocale,
        onMenuPressed: _noop,
        onNavigate: _ignoreRoute,
        account: account,
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Search TradeSquare'),
          width < 768 ? findsOneWidget : findsNothing);
      expect(find.text('TradeSquare'),
          width >= 768 ? findsOneWidget : findsNothing);
      expect(tester.getSize(find.byType(TradeSquareTopBar)).width, width);
    });
  }

  testWidgets('submits desktop search with keyboard', (tester) async {
    await _setViewport(tester, 1024);
    String? query;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: _ignoreRoute,
          onSearchSubmitted: (value) => query = value,
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'coffee suppliers');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    expect(query, 'coffee suppliers');
  });

  testWidgets('exposes image and voice search only through host callbacks',
      (tester) async {
    await _setViewport(tester, 1024);
    var imageSearchRequested = false;
    var voiceSearchRequested = false;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: _ignoreRoute,
          onImageSearch: () => imageSearchRequested = true,
          onVoiceSearch: () => voiceSearchRequested = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Search with an image'));
    await tester.tap(find.byTooltip('Search with your voice'));

    expect(imageSearchRequested, isTrue);
    expect(voiceSearchRequested, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile search exposes host image and voice actions',
      (tester) async {
    await _setViewport(tester, 390);
    var imageSearchRequested = false;
    var voiceSearchRequested = false;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: _ignoreRoute,
          onImageSearch: () => imageSearchRequested = true,
          onVoiceSearch: () => voiceSearchRequested = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Search TradeSquare'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search with an image'));
    await tester.tap(find.byTooltip('Search with your voice'));

    expect(imageSearchRequested, isTrue);
    expect(voiceSearchRequested, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile search opens a dialog and submits the query',
      (tester) async {
    await _setViewport(tester, 390);
    String? query;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: _ignoreRoute,
          onSearchSubmitted: (value) => query = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Search TradeSquare'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'grain buyers');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(query, 'grain buyers');
  });

  testWidgets('create menu only shows and navigates to configured actions',
      (tester) async {
    await _setViewport(tester, 1280);
    String? destination;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: (route) => destination = route,
          createRoutes: const {
            TradeSquareCreateAction.productListing: '/products/new',
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Add Product Listing'), findsOneWidget);
    expect(find.text('Create Buying Request'), findsNothing);
    await tester.tap(find.text('Add Product Listing'));

    expect(destination, '/products/new');
  });

  testWidgets('notification panel displays empty, loading, error and data',
      (tester) async {
    await _setViewport(tester, 430);
    await tester.pumpWidget(_app(
      const TradeSquareTopBar(
        locale: Locale('en'),
        onLocaleChanged: _ignoreLocale,
        onMenuPressed: _noop,
        onNavigate: _ignoreRoute,
      ),
    ));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up."), findsOneWidget);
    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(
      const TradeSquareTopBar(
        locale: Locale('en'),
        onLocaleChanged: _ignoreLocale,
        onMenuPressed: _noop,
        onNavigate: _ignoreRoute,
        notificationState: TradeSquareNotificationState.loading,
      ),
    ));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(
      const TradeSquareTopBar(
        locale: Locale('en'),
        onLocaleChanged: _ignoreLocale,
        onMenuPressed: _noop,
        onNavigate: _ignoreRoute,
        notificationState: TradeSquareNotificationState.error,
      ),
    ));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load notifications."), findsOneWidget);
    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();

    TradeSquareNotification? marked;
    String? destination;
    await tester.pumpWidget(_app(
      TradeSquareTopBar(
        locale: const Locale('en'),
        onLocaleChanged: _ignoreLocale,
        onMenuPressed: _noop,
        onNavigate: (route) => destination = route,
        notifications: const [
          TradeSquareNotification(
            title: 'Order update',
            description: 'A supplier replied to your request.',
            timeLabel: '5 min',
            destination: '/requests/1',
          ),
        ],
        unreadNotificationCount: 1,
        onMarkNotificationRead: (notification) => marked = notification,
      ),
    ));
    await tester.tap(find.byTooltip('1 unread notifications'));
    await tester.pump();
    expect(find.text('Order update'), findsOneWidget);
    await tester.tap(find.text('Order update'));
    await tester.pumpAndSettle();
    expect(marked?.title, 'Order update');
    expect(destination, '/requests/1');
  });

  testWidgets('profile menu selects any of the four locales and routes account',
      (tester) async {
    await _setViewport(tester, 1280);
    Locale? selectedLocale;
    String? destination;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: (locale) => selectedLocale = locale,
          onMenuPressed: _noop,
          onNavigate: (route) => destination = route,
          account: account,
          routes: const {
            TradeSquareDestination.businessProfile: '/business',
            TradeSquareDestination.settings: '/settings',
            TradeSquareDestination.helpSupport: '/support',
          },
        ),
      ),
    );

    await tester.tap(_profileMenuButton);
    await tester.pumpAndSettle();
    expect(find.text('Kiswahili'), findsOneWidget);
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();
    expect(selectedLocale, const Locale('sw'));

    await tester.tap(_profileMenuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business Profile'));
    expect(destination, '/business');
  });

  testWidgets('localizes visible search and account labels in four languages',
      (tester) async {
    const locales = ['en', 'rw', 'sw', 'fr'];
    for (final languageCode in locales) {
      await _setViewport(tester, 390);
      await tester.pumpWidget(
        _app(
          TradeSquareTopBar(
            locale: Locale(languageCode),
            onLocaleChanged: _ignoreLocale,
            onMenuPressed: _noop,
            onNavigate: _ignoreRoute,
            account: account,
          ),
          locale: Locale(languageCode),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: languageCode);
      await tester.tap(
        find.byTooltip(
          switch (languageCode) {
            'rw' => 'Shakisha muri TradeSquare',
            'sw' => 'Tafuta kwenye TradeSquare',
            'fr' => 'Rechercher dans TradeSquare',
            _ => 'Search TradeSquare',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(IconButton),
      ));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('account menu sign-out requires confirmation', (tester) async {
    await _setViewport(tester, 1280);
    var signedOut = false;
    await tester.pumpWidget(
      _app(
        TradeSquareTopBar(
          locale: const Locale('en'),
          onLocaleChanged: _ignoreLocale,
          onMenuPressed: _noop,
          onNavigate: _ignoreRoute,
          account: account,
          onSignOut: () async => signedOut = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Amahle Niyonzima, East Africa Trading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });
}

Widget _app(
  TradeSquareTopBar bar, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    theme: AppTheme.light,
    localizationsDelegates: TradeSquareLocalizations.delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: PreferredSize(
        preferredSize: bar.preferredSize,
        child: bar,
      ),
      body: const SizedBox.expand(),
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _ignoreLocale(Locale locale) {}

void _ignoreRoute(String route) {}

void _noop() {}

final _profileMenuButton = find.byWidgetPredicate(
  (widget) =>
      widget is PopupMenuButton &&
      widget.tooltip == 'Amahle Niyonzima, East Africa Trading',
);
