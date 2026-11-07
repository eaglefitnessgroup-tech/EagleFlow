import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/stock/application/stock_out_by_quotation_service.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/stock/data/sembast_stock_repository.dart';

void main() {
  group('StockOutByQuotationService Tests', () {
    late Database db;
    late SembastQuotationRepository quotationRepo;
    late SembastProductRepository productRepo;
    late SembastStockRepository stockRepo;
    late StockOutByQuotationService service;

    setUp(() async {
      final dbName =
          'test_stock_out_by_quotation_${DateTime.now().millisecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);

      quotationRepo = SembastQuotationRepository();
      productRepo = SembastProductRepository();
      stockRepo = SembastStockRepository();
      service = StockOutByQuotationService(quotationRepository: quotationRepo);
    });

    tearDown(() async {
      await db.close();
    });

    int productCounter = 0;

    Future<Product> seedProduct({
      required String name,
      required int openingStock,
    }) async {
      productCounter++;
      final p = Product(
        id: '',
        productCode: 'PROD-$productCounter',
        name: name,
        category: 'Cat',
        brand: 'Brand',
        sellingPrice: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        openingStock: openingStock,
      );
      return await productRepo.addProduct(p);
    }

    Future<Quotation> seedQuotation(
      List<QuotationLineItem> items, {
      bool isProcessed = false,
    }) async {
      final q = Quotation(
        id: '',
        quotationNumber: '', // Will be generated on save
        customerInfo: const CustomerInfo(name: 'Test Customer', phone: ''),
        salespersonId: 'admin',
        createdDate: DateTime.now(),
        modifiedDate: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
        expectedDelivery: DateTime.now().add(const Duration(days: 2)),
        lineItems: items,
        isStockOutProcessed: isProcessed,
      );
      final saved = await quotationRepo.saveQuotation(q);
      // If we need to set isProcessed directly without service, we can save it with the flag.
      // Wait, saveQuotation creates a new one if ID is empty.
      return saved;
    }

    test('1. Successful processing', () async {
      final p1 = await seedProduct(name: 'Prod A', openingStock: 10);
      final p2 = await seedProduct(name: 'Prod B', openingStock: 5);

      final q = await seedQuotation([
        QuotationLineItem(
          id: '1',
          productId: p1.id,
          name: p1.name,
          brand: '',
          unitPrice: 10,
          quantity: 2,
        ),
        QuotationLineItem(
          id: '2',
          productId: p2.id,
          name: p2.name,
          brand: '',
          unitPrice: 20,
          quantity: 5,
        ),
      ]);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isTrue);
      expect(result.deductedCount, 2);
      expect(result.quotation?.isStockOutProcessed, isTrue);

      // Verify stock deducted
      final currentStock1 = await stockRepo.calculateCurrentStock(
        productId: p1.id,
        openingStock: p1.openingStock,
      );
      expect(currentStock1, 8); // 10 - 2

      final currentStock2 = await stockRepo.calculateCurrentStock(
        productId: p2.id,
        openingStock: p2.openingStock,
      );
      expect(currentStock2, 0); // 5 - 5

      // Verify movements
      final movements1 = await stockRepo.getMovementsForProduct(p1.id);
      expect(movements1.length, 1);
      expect(movements1.first.reference, contains(q.quotationNumber));
      expect(movements1.first.reference, contains('Quotation Stock Out'));
    });

    test('2. Insufficient stock atomic rollback', () async {
      final p1 = await seedProduct(name: 'Prod A', openingStock: 10);
      final p2 = await seedProduct(
        name: 'Prod B',
        openingStock: 3,
      ); // Insufficient

      final q = await seedQuotation([
        QuotationLineItem(
          id: '1',
          productId: p1.id,
          name: p1.name,
          brand: '',
          unitPrice: 10,
          quantity: 2,
        ),
        QuotationLineItem(
          id: '2',
          productId: p2.id,
          name: p2.name,
          brand: '',
          unitPrice: 20,
          quantity: 5,
        ),
      ]);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isFalse);
      expect(result.message, contains('Insufficient stock for "Prod B"'));
      expect(
        result.quotation?.isStockOutProcessed,
        isFalse,
      ); // The object returned has false

      // Verify no stock deducted
      final currentStock1 = await stockRepo.calculateCurrentStock(
        productId: p1.id,
        openingStock: p1.openingStock,
      );
      expect(currentStock1, 10);

      final currentStock2 = await stockRepo.calculateCurrentStock(
        productId: p2.id,
        openingStock: p2.openingStock,
      );
      expect(currentStock2, 3);

      // Verify quotation not processed in DB
      final savedQ = await quotationRepo.getQuotationByNumber(
        q.quotationNumber,
      );
      expect(savedQ?.isStockOutProcessed, isFalse);
    });

    test('3. Duplicate processing is blocked', () async {
      final p1 = await seedProduct(name: 'Prod A', openingStock: 10);

      final q = await seedQuotation([
        QuotationLineItem(
          id: '1',
          productId: p1.id,
          name: p1.name,
          brand: '',
          unitPrice: 10,
          quantity: 2,
        ),
      ], isProcessed: true);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isFalse);
      expect(result.message, contains('already been processed'));

      final movements = await stockRepo.getMovementsForProduct(p1.id);
      expect(movements, isEmpty);
    });

    test('4. Custom item handling', () async {
      final p1 = await seedProduct(name: 'Prod A', openingStock: 10);

      final q = await seedQuotation([
        QuotationLineItem(
          id: '1',
          productId: p1.id,
          name: p1.name,
          brand: '',
          unitPrice: 10,
          quantity: 2,
        ),
        const QuotationLineItem(
          id: '2',
          productId: null,
          name: 'Custom Service',
          brand: '',
          unitPrice: 50,
          quantity: 1,
          isCustom: true,
        ),
      ]);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isTrue);
      expect(result.deductedCount, 1); // Only 1 stock item

      final currentStock1 = await stockRepo.calculateCurrentStock(
        productId: p1.id,
        openingStock: p1.openingStock,
      );
      expect(currentStock1, 8);
    });

    test('5. Missing product rolls back', () async {
      final p1 = await seedProduct(name: 'Prod A', openingStock: 10);

      final q = await seedQuotation([
        QuotationLineItem(
          id: '1',
          productId: p1.id,
          name: p1.name,
          brand: '',
          unitPrice: 10,
          quantity: 2,
        ),
        const QuotationLineItem(
          id: '2',
          productId: 'missing_id_123',
          name: 'Deleted Prod',
          brand: '',
          unitPrice: 20,
          quantity: 1,
        ),
      ]);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isFalse);
      expect(result.message, contains('not found in database'));

      final currentStock1 = await stockRepo.calculateCurrentStock(
        productId: p1.id,
        openingStock: p1.openingStock,
      );
      expect(currentStock1, 10); // Rolled back
    });

    test('6. No eligible stock items', () async {
      final q = await seedQuotation([
        const QuotationLineItem(
          id: '1',
          productId: null,
          name: 'Service',
          brand: '',
          unitPrice: 50,
          quantity: 1,
          isCustom: true,
        ),
      ]);

      final result = await service.processStockOut(q.quotationNumber);

      expect(result.success, isFalse);
      expect(result.message, contains('No eligible stock items'));
    });

    test('7. Invalid quotation number', () async {
      final result = await service.processStockOut('INVALID-123');

      expect(result.success, isFalse);
      expect(result.message, contains('not found'));

      final emptyResult = await service.processStockOut('');
      expect(emptyResult.success, isFalse);
      expect(emptyResult.message, contains('cannot be empty'));
    });

    test(
      '8. Remote duplicate response never creates a second local movement',
      () async {
        final product = await seedProduct(name: 'Prod A', openingStock: 10);
        final quotation = await seedQuotation([
          QuotationLineItem(
            id: '1',
            productId: product.id,
            name: product.name,
            brand: '',
            unitPrice: 10,
            quantity: 2,
          ),
        ]);
        var callCount = 0;
        service = StockOutByQuotationService(
          quotationRepository: quotationRepo,
          remoteProcessor: (number) async {
            callCount++;
            if (callCount > 1) {
              return {
                'success': true,
                'already_processed': true,
                'quotation_id': quotation.id,
                'quotation_number': number,
                'deducted_count': 0,
                'movements': <Map<String, dynamic>>[],
              };
            }
            return {
              'success': true,
              'already_processed': false,
              'quotation_id': quotation.id,
              'quotation_number': number,
              'deducted_count': 1,
              'processed_at': '2026-11-06T08:00:00Z',
              'movements': [
                {
                  'id': '11111111-1111-4111-8111-111111111111',
                  'product_id': product.id,
                  'type': 'stockOut',
                  'quantity': 2,
                  'reference':
                      'Reason: Quotation Stock Out | Quotation: $number',
                  'movement_date': '2026-11-06T08:00:00Z',
                  'created_at': '2026-11-06T08:00:00Z',
                  'created_by': 'ADMIN-001',
                },
              ],
            };
          },
        );

        final first = await service.processStockOut(quotation.quotationNumber);
        expect(first.success, isTrue);
        expect(first.deductedCount, 1);

        // Simulate a stale client cache retry after the server already
        // committed the first request.
        await quotationRepo.saveQuotation(
          quotation.copyWith(isStockOutProcessed: false),
        );
        final duplicate = await service.processStockOut(
          quotation.quotationNumber,
        );

        expect(duplicate.success, isFalse);
        expect(duplicate.message, contains('already been processed'));
        expect(callCount, 2);
        final movements = await stockRepo.getMovementsForProduct(product.id);
        expect(movements, hasLength(1));
        expect(movements.single.id, '11111111-1111-4111-8111-111111111111');
        final cachedQuotation = await quotationRepo.getQuotationByNumber(
          quotation.quotationNumber,
        );
        expect(cachedQuotation?.isStockOutProcessed, isTrue);
      },
    );

    test(
      '9. Remote transaction failure is returned without local writes',
      () async {
        final product = await seedProduct(name: 'Prod A', openingStock: 10);
        final quotation = await seedQuotation([
          QuotationLineItem(
            id: '1',
            productId: product.id,
            name: product.name,
            brand: '',
            unitPrice: 10,
            quantity: 2,
          ),
        ]);
        service = StockOutByQuotationService(
          quotationRepository: quotationRepo,
          remoteProcessor: (_) async {
            throw Exception(
              'Insufficient stock for "Prod A". Available: 1, Required: 2.',
            );
          },
        );

        final result = await service.processStockOut(quotation.quotationNumber);

        expect(result.success, isFalse);
        expect(result.message, contains('Insufficient stock for "Prod A"'));
        expect(await stockRepo.getMovementsForProduct(product.id), isEmpty);
        final cachedQuotation = await quotationRepo.getQuotationByNumber(
          quotation.quotationNumber,
        );
        expect(cachedQuotation?.isStockOutProcessed, isFalse);
      },
    );
  });
}
