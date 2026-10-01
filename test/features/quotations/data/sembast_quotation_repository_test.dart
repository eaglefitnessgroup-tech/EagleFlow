import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/blob.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/application/quotation_family.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';

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

    for (final revisionNo in [1, 2]) {
      test(
        'duplicate R$revisionNo is cached as an independent original',
        () async {
          final source = QuotationDefaults.createEmptyDraft().copyWith(
            id: 'revision-$revisionNo',
            quotationNumber: 'QT-AN-0027-26',
            baseQuotationId: 'original-id',
            revisionNo: revisionNo,
            customerNotes: 'R$revisionNo snapshot',
          );

          final duplicated = await repository.duplicateQuotation(source);
          final reopened = await repository.getQuotationByNumber(
            duplicated.quotationNumber,
          );

          expect(duplicated.id, isNot(source.id));
          expect(duplicated.quotationNumber, isNot(source.quotationNumber));
          expect(duplicated.baseQuotationId, isNull);
          expect(duplicated.revisionNo, 0);
          expect(duplicated.customerNotes, 'R$revisionNo snapshot');
          expect(reopened, isNotNull);
          expect(reopened!.baseQuotationId, isNull);
          expect(reopened.revisionNo, 0);
        },
      );
    }

    test(
      'saved and reopened quotation preserves its salesperson owner',
      () async {
        final draft = QuotationDefaults.createEmptyDraft(
          salespersonId: 'SALES-005',
        );

        final saved = await repository.saveQuotation(draft);
        final reopened = await repository.getQuotationByNumber(
          saved.quotationNumber,
        );

        expect(saved.salespersonId, 'SALES-005');
        expect(reopened, isNotNull);
        expect(reopened!.salespersonId, 'SALES-005');
      },
    );

    test(
      'saved and reopened quotation preserves the condition snapshot',
      () async {
        final draft = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: const [
            QuotationLineItem(
              id: 'condition-item',
              name: 'Display Product',
              brand: 'Brand',
              condition: ProductCondition.display,
              unitPrice: 10,
              quantity: 1,
            ),
          ],
        );
        final saved = await repository.saveQuotation(draft);
        final reopened = await repository.getQuotationByNumber(
          saved.quotationNumber,
        );
        expect(reopened, isNotNull);
        expect(reopened!.lineItems.single.condition, ProductCondition.display);
      },
    );

    test(
      'saved and reopened quotation preserves reordered item order',
      () async {
        QuotationLineItem item(String id) => QuotationLineItem(
          id: id,
          name: 'Item $id',
          brand: 'Brand',
          unitPrice: 10,
          quantity: 1,
        );
        final reordered = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: [item('c'), item('a'), item('b')],
        );

        final saved = await repository.saveQuotation(reordered);
        final reopened = await repository.getQuotationByNumber(
          saved.quotationNumber,
        );

        expect(reopened, isNotNull);
        expect(reopened!.lineItems.map((item) => item.id), ['c', 'a', 'b']);
      },
    );

    test('multiple revisions with the same quotation number coexist', () async {
      final original = QuotationDefaults.createEmptyDraft().copyWith(
        id: 'revision-base',
        quotationNumber: 'QT-AN-0027-26',
      );
      final revision1 = original.copyWith(
        id: 'revision-1',
        baseQuotationId: original.id,
        revisionNo: 1,
      );
      final revision2 = original.copyWith(
        id: 'revision-2',
        baseQuotationId: original.id,
        revisionNo: 2,
      );

      await repository.saveQuotation(original);
      await repository.saveQuotation(revision1);
      await repository.saveQuotation(revision2);

      final saved = await repository.getAllQuotations();
      expect(saved, hasLength(3));
      expect(saved.map((quotation) => quotation.id).toSet(), {
        'revision-base',
        'revision-1',
        'revision-2',
      });
      expect(saved.map((quotation) => quotation.quotationNumber).toSet(), {
        'QT-AN-0027-26',
      });
      expect(saved.map((quotation) => quotation.revisionNo).toSet(), {0, 1, 2});
    });

    test('deleting latest R2 leaves R1 latest without renumbering', () async {
      final original = QuotationDefaults.createEmptyDraft().copyWith(
        id: 'delete-base',
        quotationNumber: 'QT-DELETE-26',
      );
      final r1 = original.copyWith(
        id: 'delete-r1',
        baseQuotationId: original.id,
        revisionNo: 1,
      );
      final r2 = original.copyWith(
        id: 'delete-r2',
        baseQuotationId: original.id,
        revisionNo: 2,
      );
      await repository.saveQuotation(original);
      await repository.saveQuotation(r1);
      await repository.saveQuotation(r2);

      await repository.deleteQuotation(r2.id);

      final saved = await repository.getAllQuotations();
      final family = groupQuotationFamilies(saved).single;
      expect(family.latest.id, r1.id);
      expect(family.latest.revisionNo, 1);
      expect(family.members.map((quotation) => quotation.revisionNo), [0, 1]);
    });
  });
}
