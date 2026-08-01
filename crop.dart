import 'dart:io';
import 'package:image/image.dart';

void main() {
  final inputPath = 'assets/logos/logo_head.png';
  final outputPath = 'assets/logos/logo_head_cropped.png';

  final bytes = File(inputPath).readAsBytesSync();
  final image = decodePng(bytes);

  if (image == null) {
    print('Failed to decode image.');
    return;
  }

  print(
    'Original size: ' +
        image.width.toString() +
        ' x ' +
        image.height.toString(),
  );

  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (minX > maxX || minY > maxY) {
    print('Image is completely empty or transparent.');
    return;
  }

  print(
    'Alpha bounding box: x=' +
        minX.toString() +
        ', y=' +
        minY.toString() +
        ', w=' +
        (maxX - minX + 1).toString() +
        ', h=' +
        (maxY - minY + 1).toString(),
  );

  final cropped = copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  File(outputPath).writeAsBytesSync(encodePng(cropped));

  print(
    'Cropped size: ' +
        cropped.width.toString() +
        ' x ' +
        cropped.height.toString(),
  );
  print('Saved to ' + outputPath);
}
