import 'dart:typed_data';

import 'package:eagleflow/features/products/presentation/widgets/image_adjust_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const viewportSize = 300.0;

  group('ImageAdjustDialog scale behavior', () {
    testWidgets('initial fitted scale remains unchanged and can zoom out', (
      tester,
    ) async {
      final bytes = _solidImage(width: 200, height: 100);
      await _pumpDialog(tester, bytes);

      final slider = _slider(tester);
      const fittedScale = 3.0;

      expect(slider.value, closeTo(fittedScale, 0.0001));
      expect(slider.min, closeTo(fittedScale * 0.45, 0.0001));
      expect(slider.min, lessThan(fittedScale));

      slider.onChanged!(slider.min);
      await tester.pump();

      final controller = _viewer(tester).transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(slider.min, 0.0001));
      expect(200 * slider.min, lessThan(viewportSize));
      expect(100 * slider.min, lessThan(viewportSize));
    });

    testWidgets('preview canvas is pure white', (tester) async {
      await _pumpDialog(tester, _solidImage(width: 100, height: 100));

      final canvas = tester.widget<Container>(
        find.byKey(const Key('image_adjust_canvas')),
      );
      final decoration = canvas.decoration! as BoxDecoration;

      expect(decoration.color, Colors.white);
    });

    testWidgets('panning still works while zoomed out', (tester) async {
      await _pumpDialog(tester, _solidImage(width: 200, height: 100));

      final slider = _slider(tester);
      slider.onChanged!(slider.min);
      await tester.pump();

      final controller = _viewer(tester).transformationController!;
      final before = controller.value.getTranslation();
      await tester.drag(find.byType(InteractiveViewer), const Offset(24, 18));
      await tester.pump();
      final after = controller.value.getTranslation();

      expect(after.x, isNot(closeTo(before.x, 0.001)));
      expect(after.y, isNot(closeTo(before.y, 0.001)));
      expect(controller.value.getMaxScaleOnAxis(), closeTo(slider.min, 0.0001));
    });

    testWidgets('Reset restores fitted scale and centered position', (
      tester,
    ) async {
      await _pumpDialog(tester, _solidImage(width: 200, height: 100));

      final slider = _slider(tester);
      slider.onChanged!(slider.min);
      await tester.pump();
      await tester.drag(find.byType(InteractiveViewer), const Offset(20, 12));
      await tester.pump();

      await tester.tap(find.byKey(const Key('image_adjust_reset')));
      await tester.pump();

      final matrix = _viewer(tester).transformationController!.value;
      final translation = matrix.getTranslation();
      expect(matrix.getMaxScaleOnAxis(), closeTo(3.0, 0.0001));
      expect(translation.x, closeTo(-150.0, 0.0001));
      expect(translation.y, closeTo(0.0, 0.0001));
      expect(_slider(tester).value, closeTo(3.0, 0.0001));
    });

    testWidgets('existing zoom-in behavior remains available', (tester) async {
      await _pumpDialog(tester, _solidImage(width: 200, height: 100));

      final slider = _slider(tester);
      expect(slider.max, closeTo(12.0, 0.0001));

      slider.onChanged!(6.0);
      await tester.pump();

      expect(
        _viewer(tester).transformationController!.value.getMaxScaleOnAxis(),
        closeTo(6.0, 0.0001),
      );
    });
  });

  test('zoom range is derived from fitted scale for varied image sizes', () {
    for (final fittedScale in [0.25, 0.5, 1.0, 3.0, 10.0]) {
      expect(
        imageAdjustMinimumScale(fittedScale),
        closeTo(fittedScale * 0.45, 0.0001),
      );
    }
  });

  test(
    'Apply renderer preserves white padding and original aspect ratio',
    () async {
      final source = _solidImage(width: 200, height: 100);
      const fittedScale = 3.0;
      final zoomedOutScale = imageAdjustMinimumScale(fittedScale);
      final rendered = await renderAdjustedProductImage({
        'bytes': source,
        'viewportSize': viewportSize,
        'outputSize': 100,
        'scale': zoomedOutScale,
        'offsetX': (viewportSize - (200 * zoomedOutScale)) / 2,
        'offsetY': (viewportSize - (100 * zoomedOutScale)) / 2,
      });

      final output = img.decodeJpg(rendered)!;
      expect(output.width, 100);
      expect(output.height, 100);

      final corner = output.getPixel(0, 0);
      expect(corner.r.toInt(), 255);
      expect(corner.g.toInt(), 255);
      expect(corner.b.toInt(), 255);

      final bounds = _strongRedBounds(output);
      expect(bounds.width / bounds.height, closeTo(2.0, 0.08));
      expect(bounds.width, lessThan(output.width));
      expect(bounds.height, lessThan(output.height));

      final center = output.getPixel(output.width ~/ 2, output.height ~/ 2);
      expect(center.r.toInt(), greaterThan(240));
      expect(center.g.toInt(), lessThan(20));
      expect(center.b.toInt(), lessThan(20));
    },
  );
}

Future<void> _pumpDialog(WidgetTester tester, Uint8List bytes) async {
  await tester.binding.setSurfaceSize(const Size(500, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(500, 800)),
        child: Scaffold(body: ImageAdjustDialog(imageBytes: bytes)),
      ),
    ),
  );
  for (
    var attempt = 0;
    attempt < 10 &&
        find.byKey(const Key('image_adjust_zoom_slider')).evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byKey(const Key('image_adjust_zoom_slider')), findsOneWidget);
}

Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(const Key('image_adjust_zoom_slider')));

InteractiveViewer _viewer(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));

Uint8List _solidImage({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

({int width, int height}) _strongRedBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.r > 200 && pixel.g < 50 && pixel.b < 50) {
        minX = mathMin(minX, x);
        minY = mathMin(minY, y);
        maxX = mathMax(maxX, x);
        maxY = mathMax(maxY, y);
      }
    }
  }

  return (width: maxX - minX + 1, height: maxY - minY + 1);
}

int mathMin(int a, int b) => a < b ? a : b;
int mathMax(int a, int b) => a > b ? a : b;
