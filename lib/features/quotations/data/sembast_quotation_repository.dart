import 'dart:typed_data';
import 'package:sembast/sembast.dart';
import 'package:sembast/blob.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../domain/quotation.dart';
import '../domain/quotation_status.dart';
import '../domain/quotation_line_item.dart';
import 'quotation_repository.dart';

class SembastQuotationRepository implements QuotationRepository {
  final StoreRef<String, Map<String, dynamic>> _quotationsStore =
      StoreRef<String, Map<String, dynamic>>('quotations');
  final StoreRef<String, Blob> _imagesStore = StoreRef<String, Blob>('images');
  final StoreRef<String, int> _metadataStore = StoreRef<String, int>(
    'metadata',
  );

  final Uuid _uuid = const Uuid();

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<List<Quotation>> getAllQuotations() async {
    final db = await _db;
    final records = await _quotationsStore.find(db);
    // Sort newest first by default
    final quotations = records.map((r) => Quotation.fromJson(r.value)).toList();
    quotations.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return quotations;
  }

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async {
    final db = await _db;
    final cleanNumber = quotationNumber.trim();
    final finder = Finder(
      filter: Filter.equals('quotationNumber', cleanNumber),
    );
    final record = await _quotationsStore.findFirst(db, finder: finder);
    if (record != null) {
      return Quotation.fromJson(record.value);
    }
    return null;
  }

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    final db = await _db;
    final updatedItems = <QuotationLineItem>[];
    for (var item in quotation.lineItems) {
      if (item.isCustom && item.imageId != null && item.imageBytes == null) {
        final blob = await _imagesStore.record(item.imageId!).get(db);
        if (blob != null) {
          updatedItems.add(item.copyWith(imageBytes: blob.bytes));
        } else {
          updatedItems.add(item);
        }
      } else {
        updatedItems.add(item);
      }
    }
    return quotation.copyWith(lineItems: updatedItems);
  }

  Future<String> getNextQuotationNumber() async {
    final db = await _db;
    return await generateNextQuotationNumber(db);
  }

  Future<String> generateNextQuotationNumber(DatabaseClient client) async {
    final currentYear = DateTime.now().year % 100;
    final yearKey = 'seq_$currentYear';
    final currentSeq = await _metadataStore.record(yearKey).get(client) ?? 0;
    final nextSeq = currentSeq + 1;
    await _metadataStore.record(yearKey).put(client, nextSeq);
    return 'QT-${nextSeq.toString().padLeft(4, '0')}-$currentYear';
  }

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    final db = await _db;
    Quotation updatedQuotation = quotation;

    await db.transaction((txn) async {
      // 1. Check if new or update
      if (updatedQuotation.id.isEmpty) {
        // Generate new ID and Quotation Number
        final newId = _uuid.v4();
        final qtNumber = await generateNextQuotationNumber(txn);
        updatedQuotation = updatedQuotation.copyWith(
          id: newId,
          quotationNumber: qtNumber,
          createdDate: DateTime.now(),
          modifiedDate: DateTime.now(),
        );
      } else {
        updatedQuotation = updatedQuotation.copyWith(
          modifiedDate: DateTime.now(),
        );
      }

      // 2. Handle image additions/updates and find orphans
      final newItems = <QuotationLineItem>[];
      final previousRecord = await _quotationsStore
          .record(updatedQuotation.id)
          .get(txn);
      Quotation? previousQuotation;
      if (previousRecord != null) {
        previousQuotation = Quotation.fromJson(previousRecord);
      }

      for (var item in updatedQuotation.lineItems) {
        if (item.isCustom && item.imageBytes != null) {
          if (item.imageId == null || item.imageId!.isEmpty) {
            final newImageId = _uuid.v4();
            await _imagesStore
                .record(newImageId)
                .put(txn, Blob(item.imageBytes!));
            newItems.add(item.copyWith(imageId: newImageId));
          } else {
            // Unchanged image or replaced but kept ID
            await _imagesStore
                .record(item.imageId!)
                .put(txn, Blob(item.imageBytes!));
            newItems.add(item);
          }
        } else {
          newItems.add(item);
        }
      }

      updatedQuotation = updatedQuotation.copyWith(lineItems: newItems);

      // 3. Cleanup orphans
      if (previousQuotation != null) {
        final currentImageIds = updatedQuotation.lineItems
            .map((e) => e.imageId)
            .where((id) => id != null && id.isNotEmpty)
            .toSet();
        final previousImageIds = previousQuotation.lineItems
            .map((e) => e.imageId)
            .where((id) => id != null && id.isNotEmpty)
            .toSet();
        for (var oldId in previousImageIds) {
          if (!currentImageIds.contains(oldId)) {
            await _imagesStore.record(oldId!).delete(txn);
          }
        }
      }

      // 4. Save JSON mapping
      final dto = updatedQuotation.toJson();
      // Remove large bytes from DTO manually just in case
      for (var itemDto in dto['lineItems'] as List<dynamic>) {
        itemDto.remove('imageBytes'); // shouldn't exist in toJson anyway
      }

      await _quotationsStore.record(updatedQuotation.id).put(txn, dto);
    });

    return updatedQuotation;
  }

  @override
  Future<void> deleteQuotation(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final record = await _quotationsStore.record(id).get(txn);
      if (record != null) {
        final q = Quotation.fromJson(record);
        for (var item in q.lineItems) {
          if (item.imageId != null && item.imageId!.isNotEmpty) {
            await _imagesStore.record(item.imageId!).delete(txn);
          }
        }
        await _quotationsStore.record(id).delete(txn);
      }
    });
  }

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async {
    final db = await _db;
    Quotation duplicatedQuotation = sourceQuotation;
    await db.transaction((txn) async {
      final newId = _uuid.v4();
      final qtNumber = await generateNextQuotationNumber(txn);
      final now = DateTime.now();

      final validityDuration = sourceQuotation.validUntil.difference(
        sourceQuotation.createdDate,
      );
      final newValidUntil = now.add(validityDuration);

      final duplicatedItems = <QuotationLineItem>[];

      for (var item in sourceQuotation.lineItems) {
        if (item.imageId != null && item.imageId!.isNotEmpty) {
          final blob = await _imagesStore.record(item.imageId!).get(txn);
          if (blob != null) {
            final newImageId = _uuid.v4();
            await _imagesStore.record(newImageId).put(txn, blob);
            duplicatedItems.add(
              item.copyWith(
                id: _uuid.v4(),
                imageId: newImageId,
                imageBytes: blob.bytes,
              ),
            );
          } else {
            duplicatedItems.add(item.copyWith(id: _uuid.v4(), imageId: null));
          }
        } else {
          duplicatedItems.add(item.copyWith(id: _uuid.v4()));
        }
      }

      duplicatedQuotation = sourceQuotation.copyWith(
        id: newId,
        quotationNumber: qtNumber,
        createdDate: now,
        modifiedDate: now,
        validUntil: newValidUntil,
        status: QuotationStatus.draft,
        lineItems: duplicatedItems,
      );

      final dto = duplicatedQuotation.toJson();
      await _quotationsStore.record(newId).put(txn, dto);
    });

    return duplicatedQuotation;
  }
}
