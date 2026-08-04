import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';

void main() {
  late SembastProductRepository repository;

  setUp(() async {
    // Open in-memory database for testing
    final db = await databaseFactoryMemory.openDatabase('test_products.db');
    DatabaseService().setDatabaseForTesting(db);

    repository = SembastProductRepository();
  });

  test(
    'init() on empty database does not seed demo products, returns 0 products',
    () async {
      await repository.init();

      final products = await repository.getAllProducts();

      expect(products, isEmpty);
      expect(products.length, 0);
    },
  );
}
