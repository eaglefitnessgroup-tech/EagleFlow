import 'package:eagleflow/features/quotations/application/quotation_family.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_list_view.dart';
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

  testWidgets('desktop original is editable and every version is revisable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final families = _revisionFamilies();
    await tester.pumpWidget(_listHarness(families: families));

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Revise'), findsNWidgets(4));
    expect(find.byKey(const Key('quotation-edit-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-edit-r1')), findsNothing);
    expect(find.byKey(const Key('quotation-edit-r2')), findsNothing);
    expect(find.byKey(const Key('quotation-edit-r3')), findsNothing);
    expect(find.byKey(const Key('quotation-revise-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quotation-actions-base')));
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
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isFalse,
    );
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quotation-actions-r1')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Revise'),
      ),
      findsNothing,
    );
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quotation-actions-r2')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isFalse,
    );
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();

    final revisionActions = find.byKey(const Key('quotation-actions-r3'));
    await tester.ensureVisible(revisionActions);
    await tester.pumpAndSettle();
    await tester.tap(revisionActions);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Revise'),
      ),
      findsNothing,
    );
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('standalone original offers Edit and Revise', (tester) async {
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
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isTrue,
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

      await tester.tap(find.byKey(const Key('quotation-actions-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(deletedId, isEmpty);
      expect(find.text('Delete Quotation'), findsNothing);
      Navigator.of(tester.element(find.text('Share'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quotation-actions-r3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Quotation'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deletedId, 'r3');
    },
  );

  testWidgets('mobile gives original Edit and every revision direct Revise', (
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
    expect(find.byKey(const Key('quotation-edit-r1')), findsNothing);
    expect(find.byKey(const Key('quotation-edit-r2')), findsNothing);
    expect(find.byKey(const Key('quotation-edit-r3')), findsNothing);
    expect(find.byKey(const Key('quotation-revise-base')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r1')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r2')), findsOneWidget);
    expect(find.byKey(const Key('quotation-revise-r3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quotation-actions-base')));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isFalse,
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
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isTrue,
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
