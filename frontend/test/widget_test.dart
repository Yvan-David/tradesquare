import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/app.dart';

void main() {
  testWidgets('TradeSquare opens the login experience', (tester) async {
    await tester.pumpWidget(const TradeSquareApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
