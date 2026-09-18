import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_a4_page.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuotationController(
      QuotationDefaults.createEmptyDraft().copyWith(
        id: 'quotation-id',
        quotationNumber: 'QT-ZOOM',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: controller),
          builder: (_) => const QuotationPreviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zoom changes by 10 percent and clamps from 60 to 160', (
    tester,
  ) async {
    await pumpPreview(tester);

    expect(find.text('100%'), findsOneWidget);
    expect(find.byType(QuotationA4Page), findsOneWidget);
    final initialPageLabel = tester
        .widget<Text>(find.textContaining('Page 1 of'))
        .data;

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byTooltip('Zoom in'), warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('160%'), findsOneWidget);

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byTooltip('Zoom out'), warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('60%'), findsOneWidget);
    expect(find.byType(QuotationA4Page), findsOneWidget);
    expect(find.text(initialPageLabel!), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-zoom-reset')));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('narrow Preview keeps compact zoom controls without overflow', (
    tester,
  ) async {
    await pumpPreview(tester, size: const Size(320, 800));

    expect(find.byKey(const Key('preview-zoom-out')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('preview-zoom-in')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();

    expect(find.text('110%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
