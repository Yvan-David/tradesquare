import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/localization/generated/app_localizations.dart';
import 'package:tradesquare/app/localization/trade_square_localizations.dart';
import 'package:tradesquare/shared/components/trade_square_footer.dart';

void main() {
  const testWidths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1440.0];

  for (final width in testWidths) {
    testWidgets('renders footer without overflow at $width logical pixels',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: TradeSquareLocalizations.delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TradeSquareFooter(version: '1.0.0'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('© 2026 TradeSquare. All rights reserved.'),
        findsNothing,
      );
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.byType(DropdownButton<Locale>), findsNothing);
      expect(tester.getSize(find.byType(TradeSquareFooter)).width,
          lessThanOrEqualTo(width));
    });
  }
}
