import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/main.dart';

void main() {
  testWidgets('Driver Dashboard Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: DriverApp(),
      ),
    );

    // Verify that the dashboard starts in OFFLINE mode.
    expect(find.text('You are Off Duty'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);

    // Tap the 'Go Online' button.
    await tester.tap(find.text('Go Online'));
    await tester.pump();

    // Verify that it changes status to ONLINE.
    expect(find.text('You are On Duty'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
  });
}
