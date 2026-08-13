import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/blob.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';

void main() {
  late Database db;
  late SembastQuotationRepository repository;

  setUp(() async {
    final dbName = 'test_${DateTime.now().millisecondsSinceEpoch}.db';
    db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);
    repository = SembastQuotationRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('SembastQuotationRepository', () {
    test(
      'saveQuotation generates ID and quotationNumber for new draft',
      () async {
        final draft = QuotationDefaults.createEmptyDraft();
        final saved = await repository.saveQuotation(draft);

        expect(saved.id, isNotEmpty);
        expect(saved.quotationNumber, startsWith('DRAFT-'));
      },
    );

    test('saveQuotation saves custom images and prevents orphans', () async {
      final draft = QuotationDefaults.createEmptyDraft();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final draftWithItem = draft.copyWith(
        lineItems: [
          const QuotationLineItem(
            id: 'item1',
            name: 'Custom',
            brand: '',
            quantity: 1,
            unitPrice: 10,
            isCustom: true,
          ).copyWith(imageBytes: bytes),
        ],
      );

      final saved = await repository.saveQuotation(draftWithItem);
      expect(saved.lineItems.first.imageId, isNotNull);

      // Verify it's in the DB
      final loaded = await repository.getQuotationWithImages(saved);
      expect(loaded.lineItems.first.imageBytes, equals(bytes));

      // Remove the item
      final removedItemDraft = saved.copyWith(lineItems: []);
      await repository.saveQuotation(removedItemDraft);

      // Verify image blob is deleted
      final StoreRef<String, Blob> imagesStore = StoreRef<String, Blob>(
        'images',
      );
      final blob = await imagesStore
          .record(saved.lineItems.first.imageId!)
          .get(db);
      expect(blob, isNull);
    });

    test('deleteQuotation deletes quotation and images', () async {
      final draft = QuotationDefaults.createEmptyDraft();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final draftWithItem = draft.copyWith(
        lineItems: [
          const QuotationLineItem(
            id: 'item1',
            name: 'Custom',
            brand: '',
            quantity: 1,
            unitPrice: 10,
            isCustom: true,
          ).copyWith(imageBytes: bytes),
        ],
      );

      final saved = await repository.saveQuotation(draftWithItem);
      expect(saved.lineItems.first.imageId, isNotNull);

      await repository.deleteQuotation(saved.id);

      final all = await repository.getAllQuotations();
      expect(all, isEmpty);

      final StoreRef<String, Blob> imagesStore = StoreRef<String, Blob>(
        'images',
      );
      final blob = await imagesStore
          .record(saved.lineItems.first.imageId!)
          .get(db);
      expect(blob, isNull);
    });

    test('duplicateQuotation copies data and clones image blobs', () async {
      final draft = QuotationDefaults.createEmptyDraft();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final draftWithItem = draft.copyWith(
        lineItems: [
          const QuotationLineItem(
            id: 'item1',
            name: 'Custom',
            brand: '',
            quantity: 1,
            unitPrice: 10,
            isCustom: true,
          ).copyWith(imageBytes: bytes),
        ],
      );

      final saved = await repository.saveQuotation(draftWithItem);

      final duplicated = await repository.duplicateQuotation(saved);

      expect(duplicated.id, isNot(saved.id));
      expect(duplicated.quotationNumber, isNot(saved.quotationNumber));

      final savedImageId = saved.lineItems.first.imageId;
      final dupImageId = duplicated.lineItems.first.imageId;

      expect(dupImageId, isNotNull);
      expect(dupImageId, isNot(savedImageId));

      final loadedDup = await repository.getQuotationWithImages(duplicated);
      expect(loadedDup.lineItems.first.imageBytes, equals(bytes));
    });
  });
}
