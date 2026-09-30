import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/selected_products_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuotationLineItem item(int index) => QuotationLineItem(
    id: 'item-$index',
    productId: 'product-$index',
    productCode: 'CODE-$index',
    name: 'Item $index',
    brand: 'Brand',
    unitPrice: 100 + index.toDouble(),
    quantity: index + 1,
    discount: index.toDouble(),
  );

  Future<_ReorderHarnessState> pumpHarness(
    WidgetTester tester, {
    required double width,
    required List<QuotationLineItem> items,
    double height = 900,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final key = GlobalKey<_ReorderHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ReorderHarness(key: key, width: width, initialItems: items),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('desktop handle reorders immediately and preserves item object', (
    tester,
  ) async {
    final items = [item(0), item(1), item(2)];
    final originalFirst = items.first;
    final state = await pumpHarness(tester, width: 900, items: items);

    expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('quotation-item-drag-handle-item-0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('quotation-item-drag-handle-item-0')),
      const Offset(0, 240),
    );
    await tester.pumpAndSettle();

    expect(state.items.map((value) => value.id), [
      'item-1',
      'item-0',
      'item-2',
    ]);
    expect(state.items[1], same(originalFirst));
    expect(state.reorderCount, 1);
  });

  testWidgets('mobile handle uses delayed long-press drag behavior', (
    tester,
  ) async {
    final state = await pumpHarness(
      tester,
      width: 500,
      height: 1100,
      items: [item(0), item(1)],
    );

    final handle = find.byKey(
      const ValueKey('quotation-item-drag-handle-item-1'),
    );
    final delayedListeners = find.byType(ReorderableDelayedDragStartListener);
    expect(delayedListeners, findsNWidgets(2));
    expect(
      tester
          .widget<ReorderableDelayedDragStartListener>(delayedListeners.last)
          .index,
      1,
    );

    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(state.items.map((value) => value.id), ['item-0', 'item-1']);
    expect(state.reorderCount, 0);
  });

  testWidgets('fields, content, and remove control never initiate dragging', (
    tester,
  ) async {
    final state = await pumpHarness(tester, width: 900, items: [item(0)]);
    final tile = find.byKey(const ValueKey('item-0'));
    final fields = find.descendant(of: tile, matching: find.byType(TextField));

    expect(fields, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      await tester.tap(fields.at(index));
      await tester.pump();
    }
    await tester.tap(find.text('Item 0'));
    await tester.pump();
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();

    expect(state.reorderCount, 0);
    expect(state.removeCount, 1);
  });

  testWidgets('long mobile item list remains scrollable without overflow', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      width: 500,
      height: 600,
      items: List.generate(12, item),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Item 0'), findsOneWidget);

    await tester.drag(find.text('Item 0'), const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Item 2'), findsOneWidget);
  });
}

class _ReorderHarness extends StatefulWidget {
  final double width;
  final List<QuotationLineItem> initialItems;

  const _ReorderHarness({
    super.key,
    required this.width,
    required this.initialItems,
  });

  @override
  State<_ReorderHarness> createState() => _ReorderHarnessState();
}

class _ReorderHarnessState extends State<_ReorderHarness> {
  late List<QuotationLineItem> items;
  int reorderCount = 0;
  int removeCount = 0;

  @override
  void initState() {
    super.initState();
    items = List<QuotationLineItem>.from(widget.initialItems);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final movedItem = items.removeAt(oldIndex);
      items.insert(newIndex, movedItem);
      reorderCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: widget.width,
        child: SelectedProductsSection(
          items: items,
          onQuantityChanged: (_, _) {},
          onUnitPriceChanged: (_, _) {},
          onDiscountChanged: (_, _) {},
          onRemove: (_) => removeCount++,
          onReorder: _reorder,
          onProductsAdded: (List<Product> _) {},
          onCustomItemAdded: (_) {},
          onCustomItemUpdated: (_, _) {},
        ),
      ),
    );
  }
}
