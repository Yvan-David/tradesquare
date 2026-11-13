import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/shared/components/trade_square_navigation_shell.dart';
import 'package:tradesquare/shared/components/trade_square_sidebar.dart';
import 'package:tradesquare/shared/navigation/trade_square_destination.dart';

const _routes = {
  TradeSquareDestination.overview: '/workspace',
  TradeSquareDestination.discover: '/discover',
  TradeSquareDestination.products: '/products',
  TradeSquareDestination.buyingRequests: '/buying-requests',
  TradeSquareDestination.connections: '/connections',
  TradeSquareDestination.messages: '/messages',
  TradeSquareDestination.aiAssistant: '/assistant',
  TradeSquareDestination.marketIntelligence: '/market',
  TradeSquareDestination.notifications: '/notifications',
  TradeSquareDestination.businessProfile: '/business',
  TradeSquareDestination.settings: '/settings',
  TradeSquareDestination.helpSupport: '/support',
};

const _account = TradeSquareAccount(
  name: 'Amahle Niyonzima',
  businessName: 'East Africa Trading',
  isVerified: true,
);

void main() {
  const widths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0, 1440.0];

  for (final width in widths) {
    testWidgets('fits and lays out navigation at $width logical pixels',
        (tester) async {
      await _setViewport(tester, width);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TradeSquareNavigationShell), findsOneWidget);
      // Sidebar starts fully collapsed on every breakpoint.
      expect(find.text('Home'), width < 768 ? findsWidgets : findsNothing);
      expect(tester.getSize(find.byType(Scaffold)).width, width);
    });
  }

  testWidgets('maps active route and routes navigation through the host',
      (tester) async {
    await _setViewport(tester, 1280);
    String? navigatedTo;
    await tester.pumpWidget(
      _app(
        currentLocation: '/messages/thread-1',
        onNavigate: (route) => navigatedTo = route,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(_isPrimary(tester, 'Messages'), isTrue);
    await tester.tap(find.text('Discover'));
    expect(navigatedTo, '/discover');
  });

  testWidgets('GoRouter keeps the active item synchronized with route changes',
      (tester) async {
    await _setViewport(tester, 1280);
    late final GoRouter router;

    Widget buildShell(Widget child) {
      return TradeSquareNavigationShell.withGoRouter(
        router: router,
        body: child,
        routes: const {
          TradeSquareDestination.overview: '/workspace',
          TradeSquareDestination.messages: '/messages',
        },
        locale: const Locale('en'),
        onLocaleChanged: (_) {},
        account: _account,
      );
    }

    router = GoRouter(
      initialLocation: '/workspace',
      routes: [
        ShellRoute(
          builder: (context, state, child) => buildShell(child),
          routes: [
            GoRoute(
              path: '/workspace',
              builder: (context, state) =>
                  const Center(child: Text('Overview page')),
            ),
            GoRoute(
              path: '/messages',
              builder: (context, state) =>
                  const Center(child: Text('Messages page')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: TradeSquareLocalizations.delegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(_isPrimary(tester, 'Home'), isTrue);

    await tester.tap(find.text('Messages').first);
    await tester.pumpAndSettle();

    expect(find.text('Messages page'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(_isPrimary(tester, 'Messages'), isTrue);
  });

  testWidgets('only exposes configured routes as interactive destinations',
      (tester) async {
    await _setViewport(tester, 1280);
    var navigations = 0;
    await tester.pumpWidget(
      _app(
        routes: const {TradeSquareDestination.overview: '/workspace'},
        onNavigate: (_) => navigations++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final discoverText = tester.widget<Text>(find.text('Discover'));
    expect(discoverText.style?.color?.a, lessThan(0.5));
    await tester.tap(find.text('Discover'));
    expect(navigations, 0);
  });

  testWidgets('hamburger opens and closes the fully hidden sidebar',
      (tester) async {
    await _setViewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    expect(find.byType(TradeSquareSidebar), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(TradeSquareSidebar), findsOneWidget);

    await tester.tap(find.byTooltip('Close navigation menu').first);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('mobile drawer opens and closes after navigation',
      (tester) async {
    await _setViewport(tester, 390);
    String? navigatedTo;
    await tester.pumpWidget(
      _app(onNavigate: (route) => navigatedTo = route),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Opportunities'), findsOneWidget);
    await tester.tap(find.text('Opportunities'));
    await tester.pumpAndSettle();

    expect(navigatedTo, '/buying-requests');
    expect(find.text('Opportunities'), findsNothing);
  });

  testWidgets('mobile sidebar presents account and primary destinations',
      (tester) async {
    await _setViewport(tester, 430);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byType(TradeSquareSidebar), findsOneWidget);
    expect(find.text('Amahle Niyonzima'), findsOneWidget);
    expect(find.text('East Africa Trading'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('My Business'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile bottom navigation shows badge and navigates',
      (tester) async {
    await _setViewport(tester, 430);
    String? navigatedTo;
    final items = TradeSquareNavigationItem.primary(
      badgeCounts: const {TradeSquareDestination.messages: 12},
    );
    await tester.pumpWidget(
      _app(
        items: items,
        onNavigate: (route) => navigatedTo = route,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('9+'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-discover-nav')), findsOneWidget);
    await tester.tap(find.text('Messages').last);
    expect(navigatedTo, '/messages');

    await tester.tap(find.byKey(const ValueKey('mobile-discover-nav')));
    expect(navigatedTo, '/discover');
  });

  testWidgets('mobile bottom navigation hides while keyboard is open',
      (tester) async {
    await _setViewport(tester, 390);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-discover-nav')), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pump();

    expect(find.byKey(const ValueKey('mobile-discover-nav')), findsNothing);
  });

  testWidgets('open sidebar shows compact badges and hides zero counts',
      (tester) async {
    await _setViewport(tester, 1024);
    final items = TradeSquareNavigationItem.primary(
      badgeCounts: const {
        TradeSquareDestination.messages: 128,
        TradeSquareDestination.buyingRequests: 0,
      },
    );
    await tester.pumpWidget(_app(items: items));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account dropdown requires confirmation before sign out',
      (tester) async {
    await _setViewport(tester, 1280);
    var signedOut = false;
    await tester.pumpWidget(
      _app(onSignOut: () async => signedOut = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuButton &&
          widget.tooltip == 'Amahle Niyonzima, East Africa Trading',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets('renders under a dark theme', (tester) async {
    await _setViewport(tester, 1280);
    await tester.pumpWidget(_app(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

bool _isPrimary(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.text(label).first);
  return text.style?.fontWeight == FontWeight.w700 ||
      text.style?.fontWeight == FontWeight.w600;
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  String currentLocation = '/workspace',
  Map<TradeSquareDestination, String> routes = _routes,
  ValueChanged<String>? onNavigate,
  List<TradeSquareNavigationItem>? items,
  Future<void> Function()? onSignOut,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    locale: locale,
    themeMode: themeMode,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A66C2)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Manrope',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A66C2),
        brightness: Brightness.dark,
      ),
    ),
    localizationsDelegates: TradeSquareLocalizations.delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TradeSquareNavigationShell(
      body: const Center(child: Text('Body')),
      currentLocation: currentLocation,
      routes: routes,
      onNavigate: onNavigate ?? (_) {},
      locale: locale,
      onLocaleChanged: (_) {},
      items: items,
      account: _account,
      onSignOut: onSignOut,
    ),
  );
}
