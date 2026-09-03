import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/di/service_locator.dart';
import '../domain/quotation.dart';
import '../domain/quotation_status.dart';
import '../domain/quotation_line_item.dart';
import '../domain/customer_info.dart';
import '../domain/quotation_charges.dart';
import 'quotation_repository.dart';
import 'sembast_quotation_repository.dart';

class SupabaseQuotationRepository implements QuotationRepository {
  final SembastQuotationRepository localCache;
  final SupabaseService supabase;

  SupabaseQuotationRepository(this.localCache, this.supabase);

  final StoreRef<String, Map<String, dynamic>> _quotationsStore =
      StoreRef<String, Map<String, dynamic>>('quotations');

  Future<Database> get _db async => await DatabaseService().database;

  Future<void>? _activeSyncFuture;

  @visibleForTesting
  bool get isConnectedToServer => supabase.isConnected;

 Future<void> init() async {
  if (!isConnectedToServer) {
    return;
  }

  await _syncQuotationsDown();
}

  @visibleForTesting
  Future<List<dynamic>> fetchQuotationsFromServer() async {
    final client = supabase.client;
    if (client == null) return [];

    final response = await client
        .from('quotations')
        .select('*, quotation_items(*)')
        .order('created_at', ascending: false);
    return response as List<dynamic>;
  }

  Future<void> _syncQuotationsDown() async {
    if (_activeSyncFuture != null) {
      return _activeSyncFuture;
    }

    _activeSyncFuture = _doSyncQuotationsDown();
    try {
      await _activeSyncFuture;
    } finally {
      _activeSyncFuture = null;
    }
  }

  Future<void> _doSyncQuotationsDown() async {
    try {
      final serverQuotations = await fetchQuotationsFromServer();

      final db = await _db;
      await db.transaction((txn) async {
        for (var row in serverQuotations) {
          try {
            final serverQ = _fromSupabase(row);
            final localRecord = await _quotationsStore
                .record(serverQ.id)
                .get(txn);

            if (localRecord == null) {
              await _quotationsStore
                  .record(serverQ.id)
                  .put(txn, serverQ.toJson());
            } else {
              final localQ = Quotation.fromJson(localRecord);
              if (serverQ.modifiedDate.isAfter(localQ.modifiedDate)) {
                await _quotationsStore
                    .record(serverQ.id)
                    .put(txn, serverQ.toJson());
              }
            }
          } catch (e) {
            // Ignore parse errors for individual rows
          }
        }
      });
    } catch (e) {
      // Ignore sync errors
    }
  }

  Future<void> handleRealtimeEvent(PostgresChangePayload payload) async {
    final table = payload.table;
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    String? quotationId;

    if (table == 'quotations') {
      if (eventType == PostgresChangeEvent.delete) {
        if (oldRecord.isNotEmpty && oldRecord['id'] != null) {
          final db = await _db;
          await _quotationsStore.record(oldRecord['id'] as String).delete(db);
          return;
        }
      } else {
        quotationId = newRecord['id'] as String?;
      }
    } else if (table == 'quotation_items') {
      if (eventType == PostgresChangeEvent.delete) {
         quotationId = oldRecord['quotation_id'] as String?;
      } else {
         quotationId = newRecord['quotation_id'] as String?;
      }
    }

    if (quotationId != null) {
      try {
        final client = supabase.client;
        if (client == null) return;
        final response = await client
            .from('quotations')
            .select('*, quotation_items(*)')
            .eq('id', quotationId)
            .maybeSingle();
            
        if (response != null) {
           final serverQ = _fromSupabase(response);
           final db = await _db;
           await _quotationsStore.record(serverQ.id).put(db, serverQ.toJson());
        } else {
           // It might have been deleted, clean up cache just in case
           final db = await _db;
           await _quotationsStore.record(quotationId).delete(db);
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Quotation _fromSupabase(Map<String, dynamic> row) {
    final itemsData = row['quotation_items'] as List<dynamic>? ?? [];
    final lineItems = itemsData.map((item) {
      return QuotationLineItem(
        id: item['id'] as String,
        productId: item['product_id'] as String?,
        productCode: item['product_code'] as String?,
        name: item['name'] as String,
        brand: item['brand'] as String? ?? '',
        unitPrice: (item['unit_price'] as num).toDouble(),
        quantity: item['quantity'] as int,
        discount: (item['discount'] as num).toDouble(),
        description: item['description'] as String?,
        isCustom: item['is_custom'] as bool? ?? false,
        isVatApplicable: item['is_vat_applicable'] as bool? ?? true,
        imagePath: item['image_storage_path'] as String?,
        imageId: item['image_id'] as String?,
      );
    }).toList();

    lineItems.sort((a, b) {
      final idxA = itemsData.indexWhere((e) => e['id'] == a.id);
      final idxB = itemsData.indexWhere((e) => e['id'] == b.id);
      final orderA = idxA >= 0
          ? (itemsData[idxA]['sort_order'] as int? ?? 0)
          : 0;
      final orderB = idxB >= 0
          ? (itemsData[idxB]['sort_order'] as int? ?? 0)
          : 0;
      return orderA.compareTo(orderB);
    });

    return Quotation(
      id: row['id'] as String,
      quotationNumber: row['quotation_number'] as String,
      salespersonId: row['salesperson_id'] as String,
      customerInfo: CustomerInfo(
        name: row['customer_name'] as String? ?? '',
        company: row['customer_company'] as String? ?? '',
        phone: row['customer_phone'] as String? ?? '',
        email: row['customer_email'] as String? ?? '',
        projectLocation: row['project_location'] as String? ?? '',
      ),
      charges: QuotationCharges(
        deliveryCharges: (row['delivery_charges'] as num?)?.toDouble() ?? 0.0,
        installationCharges:
            (row['installation_charges'] as num?)?.toDouble() ?? 0.0,
        otherCharges: (row['other_charges'] as num?)?.toDouble() ?? 0.0,
        overallDiscount: (row['overall_discount'] as num?)?.toDouble() ?? 0.0,
        vatPercentage: (row['vat_percentage'] as num?)?.toDouble() ?? 5.0,
      ),
      customerNotes: row['customer_notes'] as String? ?? '',
      internalNotes: row['internal_notes'] as String? ?? '',
      status: QuotationStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => QuotationStatus.draft,
      ),
      createdDate: DateTime.parse(row['created_at'] as String).toLocal(),
      modifiedDate: DateTime.parse(row['updated_at'] as String).toLocal(),
      validUntil: DateTime.parse(row['valid_until'] as String).toLocal(),
      expectedDelivery: row['expected_delivery'] != null
          ? DateTime.parse(row['expected_delivery'] as String).toLocal()
          : DateTime.now(),
      lineItems: lineItems,
    );
  }

  @override
Future<List<Quotation>> getAllQuotations() async {
  final user = ServiceLocator().authController.currentUser;

  // Pull latest quotations from Supabase
  if (isConnectedToServer) {
    await _syncQuotationsDown();
  }

  final all = await localCache.getAllQuotations();

  if (user != null && !user.isAdmin) {
    return all.where((q) => q.salespersonId == user.id).toList();
  }

  return all;
}

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async {
    final user = ServiceLocator().authController.currentUser;
    final q = await localCache.getQuotationByNumber(quotationNumber);
    if (q != null && user != null && !user.isAdmin) {
      if (q.salespersonId != user.id) return null;
    }
    return q;
  }

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    return await localCache.getQuotationWithImages(quotation);
  }

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    final user = ServiceLocator().authController.currentUser;
    if (user != null && !user.isAdmin) {
      if (quotation.salespersonId != user.id) {
        throw Exception(
          'Unauthorized: Cannot modify quotations belonging to others.',
        );
      }
    }

    Quotation toSave = quotation;

    if (toSave.id.isEmpty) {
      final newId = const Uuid().v4();
      final qtNumber = await localCache.getNextQuotationNumber();
      toSave = toSave.copyWith(id: newId, quotationNumber: qtNumber);
    }

    if (!isConnectedToServer && toSave.status != QuotationStatus.draft) {
      throw Exception('Cannot finalize or save a non-draft quotation offline.');
    }

    if (!isConnectedToServer) {
      throw Exception('Offline: Cannot save quotation.');
    }

    try {
      final client = supabase.client;
      if (client == null) {
        throw Exception('Supabase client is null while connected');
      }
      final rpcPayload = _buildQuotationPayload(toSave);
      
      final response = await client.rpc(
        'save_quotation',
        params: {'p_payload': rpcPayload},
      );

      if (response != null &&
          response is Map<String, dynamic> &&
          response.containsKey('error')) {
        throw Exception(response['error']);
      }
      
      if (response != null &&
          response is Map<String, dynamic> &&
          response['quotationNumber'] != null &&
          response['quotationNumber'].toString().isNotEmpty) {
        toSave = toSave.copyWith(quotationNumber: response['quotationNumber'] as String);
      }
    } catch (e) {
      throw Exception('Failed to sync quotation to remote: $e');
    }

    return await localCache.saveQuotation(toSave);
  }

  @override
  Future<void> deleteQuotation(String id) async {
    final user = ServiceLocator().authController.currentUser;
    if (!isConnectedToServer) {
      throw Exception('Cannot delete quotations offline.');
    }

    final db = await _db;
    final record = await _quotationsStore.record(id).get(db);
    if (record == null) return;
    final q = Quotation.fromJson(record);

    if (user != null && !user.isAdmin) {
      if (q.salespersonId != user.id) {
        throw Exception(
          'Unauthorized: Cannot delete quotations belonging to others.',
        );
      }
    }

    try {
      final client = supabase.client;
      if (client != null) {
        await client.from('quotations').delete().eq('id', id);
      }
    } catch (e) {
      throw Exception(
        'Failed to delete quotation from remote. Please try again.',
      );
    }

    await localCache.deleteQuotation(id);
  }

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async {
    final now = DateTime.now();
    final validityDuration = sourceQuotation.validUntil.difference(
      sourceQuotation.createdDate,
    );
    final newValidUntil = now.add(validityDuration);

    Quotation duplicated = sourceQuotation.copyWith(
      id: '',
      quotationNumber: '',
      status: QuotationStatus.draft,
      createdDate: now,
      modifiedDate: now,
      validUntil: newValidUntil,
    );

    duplicated = await localCache.getQuotationWithImages(duplicated);

    final newItems = duplicated.lineItems.map((item) {
      if (item.imageBytes != null) {
        return item.copyWith(id: const Uuid().v4(), imageId: null);
      }
      return item.copyWith(id: const Uuid().v4());
    }).toList();

    duplicated = duplicated.copyWith(lineItems: newItems);

    return await saveQuotation(duplicated);
  }

  Map<String, dynamic> _buildQuotationPayload(Quotation q) {
    return {
      'id': q.id,
      'quotation_number': q.quotationNumber,
      'salesperson_id': q.salespersonId,
      'customer_name': q.customerInfo.name,
      'customer_company': q.customerInfo.company,
      'customer_phone': q.customerInfo.phone,
      'customer_email': q.customerInfo.email,
      'project_location': q.customerInfo.projectLocation,
      'delivery_charges': q.charges.deliveryCharges,
      'installation_charges': q.charges.installationCharges,
      'other_charges': q.charges.otherCharges,
      'overall_discount': q.charges.overallDiscount,
      'vat_percentage': q.charges.vatPercentage,
      'customer_notes': q.customerNotes,
      'internal_notes': q.internalNotes,
      'status': q.status.name,
      'created_at': q.createdDate.toUtc().toIso8601String(),
      'updated_at': q.modifiedDate.toUtc().toIso8601String(),
      'valid_until': q.validUntil.toUtc().toIso8601String(),
      'expected_delivery': q.expectedDelivery.toUtc().toIso8601String(),
      'quotation_items': q.lineItems.map((e) {
        final itemId = Uuid.isValidUUID(fromString: e.id) ? e.id : const Uuid().v4();
        return {
          'id': itemId,
          'product_id': e.productId,
          'product_code': e.productCode,
          'name': e.name,
          'brand': e.brand,
          'unit_price': e.unitPrice,
          'quantity': e.quantity,
          'discount': e.discount,
          'description': e.description,
          'is_custom': e.isCustom,
          'is_vat_applicable': e.isVatApplicable,
          'image_storage_path': e.imagePath,
          'image_id': e.imageId,
        };
      }).toList(),
      // Adding camelCase fallbacks just in case the RPC uses them
      'quotationNumber': q.quotationNumber,
      'salespersonId': q.salespersonId,
      'customerInfo': q.customerInfo.toJson(),
      'charges': q.charges.toJson(),
      'lineItems': q.lineItems.map((e) {
        final itemId = Uuid.isValidUUID(fromString: e.id) ? e.id : const Uuid().v4();
        final map = e.toJson();
        map['id'] = itemId;
        map.remove('imageBytes');
        return map;
      }).toList(),
    };
  }
}
