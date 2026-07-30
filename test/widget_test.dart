import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/app/app.dart';

void main() {
  testWidgets('App starts on Splash Screen and displays title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EagleFlowApp());

    // Verify that the Splash screen title is shown.
    expect(find.text('EagleFlow'), findsOneWidget);

    // Advance time to allow the splash screen's Future.delayed to complete
    await tester.pump(const Duration(seconds: 2));

    // Allow the navigation animation to finish
    await tester.pumpAndSettle();
  });
}
