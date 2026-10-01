import 'package:eagleflow/features/quotations/application/quotation_family.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_list_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Quotation _quotation({
  required String id,
  required String number,
  String? baseId,
  int revisionNo = 0,
}) {
  return QuotationDefaults.createEmptyDraft(salespersonId: 'sales-1').copyWith(
    id: id,
    quotationNumber: number,
    baseQuotationId: baseId,
    revisionNo: revisionNo,
    customerInfo: QuotationDefaults.createEmptyDraft().customerInfo.copyWith(
      name: 'Customer $revisionNo',
    ),
  );
}

List<QuotationFamily> _revisionFamilies() {
  final original = _quotation(id: 'base', number: 'QT-AN-0027-26');
  return groupQuotationFamilies([
    original,
    _quotation(
      id: 'r1',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 1,
    ),
    _quotation(
      id: 'r2',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 2,
    ),
    _quotation(
      id: 'r3',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 3,
    ),
  ]);
}

Widget _listHarness({
  required List<QuotationFamily> families,
  ValueChanged<Quotation>? onEdit,
  ValueChanged<Quotation>? onRevise,
  ValueChanged<Quotation>? onDownload,
  ValueChanged<Quotation>? onDuplicate,
  ValueChanged<Quotation>? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: QuotationListView(
          families: families,
          onView: (_) {},
          onEdit: onEdit ?? (_) {},
          onRevise: onRevise ?? (_) {},
          onDownload: onDownload ?? (_) {},
          onDuplicate: onDuplicate ?? (_) {},
          onShare: (_) {},
          onDelete: onDelete ?? (_) {},
          onCreate: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop shows original and R1/R2/R3 as normal flat rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_listHarness(families: _revisionFamilies()));

    expect(find.text('QT-AN-0027-26'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R2'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R3'), findsOneWidget);
    expect(find.text('3 revisions'), findsNothing);
    expect(find.text('Latest'), findsNothing);
    expect(find.byKey(const Key('toggle-family-base')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop rows keep identical direct action slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final families = _revisionFamilies();
    await tester.pumpWidget(_listHarness(families: families));

    expect(find.text('View'), findsNWidgets(4));
    expect(find.text('Edit'), findsNWidgets(4));
    expect(find.text('Revise'), findsNWidgets(4));
    expect(find.text('Download'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.byTooltip('Download quotation'), findsNWidgets(4));
    expect(find.byTooltip('Delete quotation'), findsNWidgets(4));
    for (final id in ['base', 'r1', 'r2', 'r3']) {
      expect(
        find.descendant(
          of: find.byKey(Key('quotation-view-$id')),
          matching: find.byIcon(Icons.visibility_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('quotation-edit-$id')),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('quotation-revise-$id')),
          matching: find.byIcon(Icons.history),
        ),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('quotation-edit-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r3')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('quotation-edit-base')))
          .onPressed,
      isNotNull,
    );
    for (final id in ['r1', 'r2', 'r3']) {
      expect(
        tester
            .widget<TextButton>(find.byKey(Key('quotation-edit-$id')))
            .onPressed,
        isNull,
      );
    }
    expect(find.byKey(const Key('quotation-revise-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r3')), findsOneWidget);

    for (final id in ['base', 'r1', 'r2']) {
      expect(
        tester
            .widget<IconButton>(find.byKey(Key('quotation-delete-$id')))
            .onPressed,
        isNull,
      );
    }
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('quotation-delete-r3')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('quotation-actions-base')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Download'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Delete'),
      ),
      findsNothing,
    );
  });

  testWidgets('active hover animates without changing action geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_listHarness(families: _revisionFamilies()));

    final viewFinder = find.byKey(const Key('quotation-view-base'));
    final downloadFinder = find.byKey(const Key('quotation-download-base'));
    final beforeViewRect = tester.getRect(viewFinder);
    final beforeDownloadRect = tester.getRect(downloadFinder);
    final viewButton = tester.widget<TextButton>(viewFinder);
    final disabledCursor = tester
        .widget<TextButton>(find.byKey(const Key('quotation-edit-r1')))
        .style
        ?.mouseCursor
        ?.resolve({WidgetState.disabled, WidgetState.hovered});

    expect(
      viewButton.style?.animationDuration,
      const Duration(milliseconds: 140),
    );
    expect(
      viewButton.style?.mouseCursor?.resolve({WidgetState.hovered}),
      SystemMouseCursors.click,
    );
    expect(disabledCursor, SystemMouseCursors.basic);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(beforeViewRect.center);
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getRect(viewFinder), beforeViewRect);
    expect(tester.getRect(downloadFinder), beforeDownloadRect);
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getRect(viewFinder), beforeViewRect);
    expect(tester.getRect(downloadFinder), beforeDownloadRect);
    await mouse.removePointer();
  });

  testWidgets('standalone original enables Edit, Revise, and Delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = _quotation(id: 'standalone', number: 'QT-STANDALONE');

    await tester.pumpWidget(
      _listHarness(families: groupQuotationFamilies([original])),
    );

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Revise'), findsOneWidget);
    expect(find.byTooltip('Download quotation'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('quotation-delete-standalone')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('quotation-actions-standalone')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Revise'),
      ),
      findsNothing,
    );
    expect(find.text('Duplicate'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Delete'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'duplicate works on revisions and disabled delete sends no request',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var duplicatedId = '';
      var deletedId = '';

      await tester.pumpWidget(
        _listHarness(
          families: _revisionFamilies(),
          onDuplicate: (quotation) => duplicatedId = quotation.id,
          onDelete: (quotation) => deletedId = quotation.id,
        ),
      );

      await tester.tap(find.byKey(const Key('quotation-actions-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(duplicatedId, 'r1');

      await tester.tap(find.byKey(const Key('quotation-delete-r1')));
      await tester.pumpAndSettle();
      expect(deletedId, isEmpty);
      expect(find.text('Delete Quotation'), findsNothing);

      await tester.tap(find.byKey(const Key('quotation-delete-r3')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Quotation'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deletedId, 'r3');
    },
  );

  testWidgets('mobile keeps identical direct action slots and eligibility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var revisedId = '';

    await tester.pumpWidget(
      _listHarness(
        families: _revisionFamilies(),
        onRevise: (quotation) => revisedId = quotation.id,
      ),
    );

    expect(find.text('QT-AN-0027-26'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R2'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R3'), findsOneWidget);
    expect(find.byKey(const Key('toggle-family-base')), findsNothing);

    expect(find.byKey(const Key('quotation-edit-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r3')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r3')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quotation-view-base')),
        matching: find.byIcon(Icons.visibility_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quotation-edit-r1')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quotation-revise-r3')),
        matching: find.byIcon(Icons.history),
      ),
      findsOneWidget,
    );

    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('quotation-edit-r1')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('quotation-delete-base')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('quotation-actions-base')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Delete'),
      ),
      findsNothing,
    );
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();

    final r3Actions = find.byKey(const Key('quotation-actions-r3'));
    await tester.scrollUntilVisible(
      r3Actions,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(r3Actions);
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('quotation-delete-r3')))
          .onPressed,
      isNotNull,
    );
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();

    final r1Revise = find.byKey(const Key('quotation-revise-r1'));
    await tester.scrollUntilVisible(
      r1Revise,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(r1Revise);
    await tester.pumpAndSettle();

    expect(revisedId, 'r1');
    expect(tester.takeException(), isNull);
  });
}
