import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../../features/products/domain/product.dart';
import '../di/service_locator.dart';

class PdfImageLoader {
  static final Map<String, Uint8List> _cache = {};

  /// Returns the image bytes for a product.
  /// Checks memory bytes first, then cache, then downloads from Supabase.
  static Future<Uint8List?> loadProductImage(Product product) async {
    if (product.imageBytes != null && product.imageBytes!.isNotEmpty) {
      return product.imageBytes;
    }

    if (product.imageId == null || product.imageId!.isEmpty) {
      return null;
    }

    final imageId = product.imageId!;
    if (_cache.containsKey(imageId)) {
      return _cache[imageId];
    }

    try {
      final client = ServiceLocator().supabaseService.client;
      if (client != null) {
        final bytes = await client.storage
            .from('product-images')
            .download(imageId);
        _cache[imageId] = bytes;
        return bytes;
      }
    } catch (e) {
      // Ignore download errors for PDF generation
    }
    return null;
  }

  /// Loads an asset image (e.g. logo)
  static Future<Uint8List?> loadAsset(String path) async {
    if (_cache.containsKey(path)) {
      return _cache[path];
    }
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      _cache[path] = bytes;
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Returns synchronously from cache
  static Uint8List? loadProductImageSync(Product product) {
    if (product.imageBytes != null && product.imageBytes!.isNotEmpty) {
      return product.imageBytes;
    }
    if (product.imageId != null && _cache.containsKey(product.imageId!)) {
      return _cache[product.imageId!];
    }
    return null;
  }

  /// Returns synchronously from cache
  static Uint8List? loadAssetSync(String path) {
    return _cache[path];
  }
}
