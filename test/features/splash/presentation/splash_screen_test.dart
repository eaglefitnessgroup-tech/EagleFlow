import 'package:eagleflow/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash remains a neutral loading frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Preparing your workspace...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
