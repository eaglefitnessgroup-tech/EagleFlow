import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/products/presentation/widgets/product_image.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Manual Fakes for Supabase Client
class FakeSupabaseClient implements SupabaseClient {
  final FakeSupabaseStorageClient _storage;
  FakeSupabaseClient(this._storage);

  @override
  SupabaseStorageClient get storage => _storage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSupabaseStorageClient implements SupabaseStorageClient {
  final FakeStorageFileApi _fileApi;
  FakeSupabaseStorageClient(this._fileApi);

  @override
  StorageFileApi from(String id) {
    if (id == 'product-images') return _fileApi;
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageFileApi implements StorageFileApi {
  Future<Uint8List> Function(String path)? onDownload;
  int downloadCallCount = 0;

  @override
  Future<Uint8List> download(
    String path, {
    Map<String, String>? queryParams,
    TransformOptions? transform,
  }) async {
    downloadCallCount++;
    if (onDownload != null) {
      return onDownload!(path);
    }
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStorageFileApi fakeStorageFileApi;
  late FakeSupabaseStorageClient fakeStorageClient;
  late FakeSupabaseClient fakeSupabaseClient;

  final dummyProduct = Product(
    id: 'test-id',
    productCode: 'TEST01',
    name: 'Test Product',
    category: 'Test',
    brand: 'Test',
    sellingPrice: 100,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    fakeStorageFileApi = FakeStorageFileApi();
    fakeStorageClient = FakeSupabaseStorageClient(fakeStorageFileApi);
    fakeSupabaseClient = FakeSupabaseClient(fakeStorageClient);
  });

  Widget buildTestableWidget(Widget widget) {
    return MaterialApp(home: Scaffold(body: widget));
  }

  testWidgets('memory image is displayed if imageBytes is provided', (
    tester,
  ) async {
    // 1x1 transparent png
    final bytes = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      11,
      73,
      68,
      65,
      84,
      8,
      215,
      99,
      96,
      0,
      2,
      0,
      0,
      5,
      0,
      1,
      226,
      38,
      5,
      155,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]);

    final product = dummyProduct.copyWith(imageBytes: bytes);

    await tester.pumpWidget(
      buildTestableWidget(
        ProductImage(product: product, testClient: fakeSupabaseClient),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(fakeStorageFileApi.downloadCallCount, 0);
  });

  testWidgets(
    'no image fallback is displayed if both imageBytes and imageId are null',
    (tester) async {
      final product = dummyProduct.copyWith(imageBytes: null, imageId: null);

      await tester.pumpWidget(
        buildTestableWidget(
          ProductImage(product: product, testClient: fakeSupabaseClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(fakeStorageFileApi.downloadCallCount, 0);
    },
  );

  testWidgets('remote image success downloads and displays image', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      11,
      73,
      68,
      65,
      84,
      8,
      215,
      99,
      96,
      0,
      2,
      0,
      0,
      5,
      0,
      1,
      226,
      38,
      5,
      155,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]);

    fakeStorageFileApi.onDownload = (path) async => bytes;

    // Use a unique ID so it doesn't hit the static cache from previous tests
    final product = dummyProduct.copyWith(
      imageId: 'success-image-id',
      imageBytes: null,
    );

    await tester.pumpWidget(
      buildTestableWidget(
        ProductImage(product: product, testClient: fakeSupabaseClient),
      ),
    );

    // initially shows loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // displays image
    expect(find.byType(Image), findsOneWidget);
    expect(fakeStorageFileApi.downloadCallCount, 1);
  });

  testWidgets('remote image failure displays error icon', (tester) async {
    fakeStorageFileApi.onDownload = (path) async {
      throw Exception('Download failed');
    };

    final product = dummyProduct.copyWith(
      imageId: 'fail-image-id',
      imageBytes: null,
    );

    await tester.pumpWidget(
      buildTestableWidget(
        ProductImage(product: product, testClient: fakeSupabaseClient),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(fakeStorageFileApi.downloadCallCount, 1);
  });
}
