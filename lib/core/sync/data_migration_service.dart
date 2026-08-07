import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/products/domain/product.dart';
import '../../features/stock/domain/stock_movement.dart';
import '../../features/quotations/domain/quotation.dart';

class MigrationReport {
  int usersFound = 0;
  int usersInserted = 0;
  int usersSkipped = 0;
  int usersFailed = 0;

  int productsFound = 0;
  int productsInserted = 0;
  int productsSkipped = 0;
  int productsFailed = 0;

  int movementsFound = 0;
  int movementsInserted = 0;
  int movementsSkipped = 0;
  int movementsFailed = 0;

  int quotationsFound = 0;
  int quotationsInserted = 0;
  int quotationsSkipped = 0;
  int quotationsFailed = 0;

  Map<String, dynamic> toJson() => {
    'users': {
      'found': usersFound,
      'inserted': usersInserted,
      'skipped': usersSkipped,
      'failed': usersFailed,
    },
    'products': {
      'found': productsFound,
      'inserted': productsInserted,
      'skipped': productsSkipped,
      'failed': productsFailed,
    },
    'movements': {
      'found': movementsFound,
      'inserted': movementsInserted,
      'skipped': movementsSkipped,
      'failed': movementsFailed,
    },
    'quotations': {
      'found': quotationsFound,
      'inserted': quotationsInserted,
      'skipped': quotationsSkipped,
      'failed': quotationsFailed,
    },
  };
}

class DataMigrationService {
  final SupabaseClient? client;
  final Database db;

  DataMigrationService({required this.client, required this.db});

  Future<MigrationReport> migrate({bool dryRun = false}) async {
    final report = MigrationReport();
    if (client == null) {
      debugPrint('Migration: client is null, skipping');
      return report;
    }

    await _migrateUsers(report, dryRun: dryRun);
    await _migrateProducts(report, dryRun: dryRun);
    await _migrateStockMovements(report, dryRun: dryRun);
    await _migrateQuotations(report, dryRun: dryRun);

    return report;
  }

  Future<void> _migrateUsers(
    MigrationReport report, {
    required bool dryRun,
  }) async {
    final store = stringMapStoreFactory.store('users');
    final records = await store.find(db);
    report.usersFound = records.length;

    for (var record in records) {
      try {
        final localData = record.value;
        final id = localData['id'] as String;

        // Check remote
        final existing = await client!
            .from('app_users')
            .select('id')
            .eq('id', id)
            .maybeSingle();

        if (existing != null) {
          report.usersSkipped++;
          continue; // Already exists
        }

        if (!dryRun) {
          await client!.from('app_users').insert({
            'id': id,
            'name': localData['name'],
            'username': localData['username'],
            'password_hash': localData['passwordHash'],
            'role': localData['role'],
            'is_active': localData['isActive'],
            'created_at': localData['createdAt'],
          });
        }
        report.usersInserted++;
      } catch (e) {
        debugPrint('Migration: Failed to migrate user ${record.key} - $e');
        report.usersFailed++;
      }
    }
  }

  Future<void> _migrateProducts(
    MigrationReport report, {
    required bool dryRun,
  }) async {
    final store = stringMapStoreFactory.store('products');
    final records = await store.find(db);
    report.productsFound = records.length;

    for (var record in records) {
      try {
        final localData = record.value;
        final product = Product.fromJson(localData);

        final existing = await client!
            .from('products')
            .select('id, updated_at')
            .eq('id', product.id)
            .maybeSingle();

        if (existing != null) {
          final remoteDate = DateTime.parse(existing['updated_at']).toLocal();
          if (product.updatedAt.isAfter(remoteDate)) {
            if (!dryRun) {
              await client!
                  .from('products')
                  .update(_buildProductPayload(product))
                  .eq('id', product.id);
            }
            report.productsInserted++;
          } else {
            report.productsSkipped++;
          }
          continue;
        }

        if (!dryRun) {
          await client!.from('products').insert(_buildProductPayload(product));
        }
        report.productsInserted++;
      } catch (e) {
        debugPrint('Migration: Failed to migrate product ${record.key} - $e');
        report.productsFailed++;
      }
    }
  }

  Future<void> _migrateStockMovements(
    MigrationReport report, {
    required bool dryRun,
  }) async {
    final store = stringMapStoreFactory.store('stock_movements');
    final records = await store.find(db);
    report.movementsFound = records.length;

    for (var record in records) {
      try {
        final localData = record.value;
        final movement = StockMovement.fromJson(localData);

        // Immutable, so just check if it exists
        final existing = await client!
            .from('stock_movements')
            .select('id')
            .eq('id', movement.id)
            .maybeSingle();

        if (existing != null) {
          report.movementsSkipped++;
          continue;
        }

        if (!dryRun) {
          await client!
              .from('stock_movements')
              .insert(_buildMovementPayload(movement));
        }
        report.movementsInserted++;
      } catch (e) {
        debugPrint('Migration: Failed to migrate movement ${record.key} - $e');
        report.movementsFailed++;
      }
    }
  }

  Future<void> _migrateQuotations(
    MigrationReport report, {
    required bool dryRun,
  }) async {
    final store = stringMapStoreFactory.store('quotations');
    final records = await store.find(db);
    report.quotationsFound = records.length;

    for (var record in records) {
      try {
        final localData = record.value;
        final quotation = Quotation.fromJson(localData);

        // Skip drafts (can't finalize them locally if we are migrating to Supabase, but wait, maybe drafts should be migrated?
        // Wait, "quotations + quotation_items". If drafts have a `DRAFT-` number they can't be saved by RPC if it generates a number.
        // Wait, `save_quotation` RPC accepts `quotationNumber` if it is a DRAFT? The RPC generates a number IF it doesn't start with QT-, BUT wait, existing local quotations ALREADY HAVE `QT-` numbers! They are finalized. So RPC will accept their existing `QT-` numbers!
        // What about drafts? Let's just migrate everything! The RPC handles existing numbers.
        // Oh wait, if the RPC generates a number, does it override our local number?
        // We'll see how RPC was defined in Phase 7 schema!

        final existing = await client!
            .from('quotations')
            .select('id, updated_at')
            .eq('id', quotation.id)
            .maybeSingle();

        if (existing != null) {
          final remoteDate = DateTime.parse(existing['updated_at']).toLocal();
          if (quotation.modifiedDate.isAfter(remoteDate)) {
            if (!dryRun) {
              final payload = _buildQuotationPayload(quotation);
              final res = await client!.rpc(
                'save_quotation',
                params: {'p_payload': payload},
              );
              if (res != null && res is Map && res.containsKey('error')) {
                throw Exception(res['error']);
              }
            }
            report.quotationsInserted++;
          } else {
            report.quotationsSkipped++;
          }
          continue;
        }

        if (!dryRun) {
          final payload = _buildQuotationPayload(quotation);
          final res = await client!.rpc(
            'save_quotation',
            params: {'p_payload': payload},
          );
          if (res != null && res is Map && res.containsKey('error')) {
            throw Exception(res['error']);
          }
        }
        report.quotationsInserted++;
      } catch (e) {
        debugPrint('Migration: Failed to migrate quotation ${record.key} - $e');
        report.quotationsFailed++;
      }
    }
  }

  Map<String, dynamic> _buildQuotationPayload(Quotation quotation) {
    return {
      'id': quotation.id,
      'quotationNumber': quotation.quotationNumber,
      'salespersonId': quotation.salespersonId,
      'customerName': quotation.customerInfo.name,
      'customerCompany': quotation.customerInfo.company,
      'customerPhone': quotation.customerInfo.phone,
      'customerEmail': quotation.customerInfo.email,
      'projectLocation': quotation.customerInfo.projectLocation,
      'deliveryCharges': quotation.charges.deliveryCharges,
      'installationCharges': quotation.charges.installationCharges,
      'otherCharges': quotation.charges.otherCharges,
      'overallDiscount': quotation.charges.overallDiscount,
      'vatPercentage': quotation.charges.vatPercentage,
      'customerNotes': quotation.customerNotes,
      'internalNotes': quotation.internalNotes,
      'status': quotation.status.name,
      'validUntil': quotation.validUntil.toUtc().toIso8601String(),
      'expectedDelivery': quotation.expectedDelivery.toUtc().toIso8601String(),
      'lineItems': quotation.lineItems.map((e) {
        final map = e.toJson();
        map.remove('imageBytes'); // Never send bytes to RPC
        return map;
      }).toList(),
    };
  }

  Map<String, dynamic> _buildProductPayload(Product p) {
    return {
      'id': p.id,
      'product_code': p.productCode,
      'normalized_product_code': p.productCode.trim().toUpperCase(),
      'name': p.name,
      'category': p.category,
      'brand': p.brand,
      'description': p.description,
      'model_number': p.modelNumber,
      'unit': p.unit,
      'selling_price': p.sellingPrice,
      'is_vat_applicable': p.isVatApplicable,
      'is_active': p.isActive,
      'min_stock_level': p.minStockLevel,
      'opening_stock': p.openingStock,
      'notes': p.notes,
      'image_id': p.imageId,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _buildMovementPayload(StockMovement m) {
    return {
      'id': m.id,
      'product_id': m.productId,
      'type': m.type.name,
      'quantity': m.quantity,
      'reference': m.reference,
      'movement_date': m.movementDate.toUtc().toIso8601String(),
      'created_at': m.createdAt.toUtc().toIso8601String(),
      'created_by': m.createdBy,
    };
  }
}
