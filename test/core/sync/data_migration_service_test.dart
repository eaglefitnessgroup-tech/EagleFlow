import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eagleflow/core/sync/data_migration_service.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {
  Map<String, List<Map<String, dynamic>>> tables = {
    'app_users': [],
    'products': [],
    'stock_movements': [],
    'quotations': [],
    'quotation_items': [],
  };

  bool failNextInsert = false;

  @override
  SupabaseQueryBuilder from(String table) {
    return FakeSupabaseQueryBuilder(table, this);
  }

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    dynamic get,
    Map<String, dynamic>? params,
  }) {
    if (fn == 'save_quotation') {
      if (failNextInsert) {
        failNextInsert = false;
        return FakePostgrestFilterBuilder<T>(error: 'Forced RPC Error');
      }
      final payload = params!['p_payload'] as Map<String, dynamic>;

      // Update or insert quotation
      final qId = payload['id'];
      final existingIndex = tables['quotations']!.indexWhere(
        (e) => e['id'] == qId,
      );
      final remoteQ = {
        'id': qId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingIndex != -1) {
        tables['quotations']![existingIndex] = remoteQ;
      } else {
        tables['quotations']!.add(remoteQ);
      }

      // Items logic is mocked
      final items = payload['lineItems'] as List<dynamic>;
      tables['quotation_items']!.addAll(
        items.map((i) => i as Map<String, dynamic>),
      );

      return FakePostgrestFilterBuilder<T>(
        data: {'id': qId, 'quotationNumber': payload['quotationNumber']},
      );
    }
    throw UnimplementedError();
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final String table;
  final FakeSupabaseClient client;

  FakeSupabaseQueryBuilder(this.table, this.client);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder(table: table, client: client);
  }

  @override
  PostgrestFilterBuilder<PostgrestList> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    if (client.failNextInsert) {
      client.failNextInsert = false;
      throw Exception('Forced Insert Error');
    }

    if (values is Map<String, dynamic>) {
      client.tables[table]!.add(values);
    } else if (values is List) {
      for (var v in values) {
        client.tables[table]!.add(v as Map<String, dynamic>);
      }
    }
    return FakePostgrestFilterBuilder(table: table, client: client);
  }

  @override
  PostgrestFilterBuilder<PostgrestList> update(Map<dynamic, dynamic> values) {
    return FakePostgrestFilterBuilder(
      table: table,
      client: client,
      updateValues: values.cast<String, dynamic>(),
    );
  }
}

// ignore: must_be_immutable
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final String? table;
  final FakeSupabaseClient? client;
  final String? error;
  final dynamic data;
  final Map<String, dynamic>? updateValues;

  String? eqColumn;
  Object? eqValue;
  bool isSingle = false;

  FakePostgrestFilterBuilder({
    this.table,
    this.client,
    this.error,
    this.data,
    this.updateValues,
  });

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    eqColumn = column;
    eqValue = value;
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value)? onValue, {
    Function? onError,
  }) async {
    dynamic result;
    if (error != null) {
      result = {'error': error};
    } else if (data != null) {
      result = data;
    } else {
      final list = client!.tables[table!]!;
      if (eqColumn != null) {
        final match = list.where((e) => e[eqColumn] == eqValue).toList();
        if (updateValues != null && match.isNotEmpty) {
          match.first.addAll(updateValues!);
        }
        result = match;
      } else {
        result = list;
      }
    }
    if (onValue != null) {
      return await onValue(result as T);
    }
    return result as U;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(this, isSingle: true);
  }
}

class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final FakePostgrestFilterBuilder<dynamic> filter;
  final bool isSingle;

  FakePostgrestTransformBuilder(this.filter, {this.isSingle = false});

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value)? onValue, {
    Function? onError,
  }) async {
    return await filter.then<U>((dynamic list) {
      dynamic finalResult = list;
      if (isSingle && list is List) {
        finalResult = list.isEmpty ? null : list.first;
      }
      if (onValue != null) {
        return onValue(finalResult as T);
      }
      return finalResult as U;
    }, onError: onError);
  }
}

void main() {
  late Database db;
  late FakeSupabaseClient client;
  late DataMigrationService service;

  setUp(() async {
    final factory = databaseFactoryMemory;
    db = await factory.openDatabase(
      'test_migration_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    client = FakeSupabaseClient();
    service = DataMigrationService(client: client, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSembast() async {
    final userStore = stringMapStoreFactory.store('users');
    await userStore.record('ADMIN-001').put(db, {
      'id': 'ADMIN-001',
      'name': 'Admin',
      'username': 'admin',
      'passwordHash': 'hash',
      'role': 'admin',
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final productStore = stringMapStoreFactory.store('products');
    await productStore
        .record('P1')
        .put(
          db,
          Product(
            id: 'P1',
            productCode: 'PROD-1',
            name: 'Product 1',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 10,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ).toJson(),
        );

    final stockStore = stringMapStoreFactory.store('stock_movements');
    await stockStore
        .record('SM1')
        .put(
          db,
          StockMovement(
            id: 'SM1',
            productId: 'P1',
            type: StockMovementType.stockIn,
            quantity: 10,
            movementDate: DateTime.now(),
            createdAt: DateTime.now(),
            createdBy: 'ADMIN-001',
            reference: 'Initial stock',
          ).toJson(),
        );

    final quotationStore = stringMapStoreFactory.store('quotations');
    await quotationStore
        .record('Q1')
        .put(
          db,
          Quotation(
            id: 'Q1',
            quotationNumber: 'QT-0001-26',
            salespersonId: 'ADMIN-001',
            customerInfo: const CustomerInfo(name: 'Cust 1'),
            charges: const QuotationCharges(),
            status: QuotationStatus.sent,
            createdDate: DateTime.now(),
            modifiedDate: DateTime.now(),
            validUntil: DateTime.now(),
            expectedDelivery: DateTime.now(),
            lineItems: [
              QuotationLineItem(
                id: 'I1',
                productId: 'P1',
                name: 'Product 1',
                brand: 'Brand',
                unitPrice: 10,
                quantity: 2,
              ),
            ],
          ).toJson(),
        );
  }

  group('DataMigrationService Tests', () {
    test('1. First migration dry run', () async {
      await seedSembast();
      final report = await service.migrate(dryRun: true);

      expect(report.usersFound, 1);
      expect(report.usersInserted, 1);
      expect(client.tables['app_users']!.isEmpty, isTrue); // Dry run, no writes
    });

    test('2. First migration success', () async {
      await seedSembast();
      final report = await service.migrate(dryRun: false);

      expect(report.usersFound, 1);
      expect(report.usersInserted, 1);
      expect(report.usersFailed, 0);

      expect(report.productsFound, 1);
      expect(report.productsInserted, 1);

      expect(report.movementsFound, 1);
      expect(report.movementsInserted, 1);

      expect(report.quotationsFound, 1);
      expect(report.quotationsInserted, 1);

      expect(client.tables['app_users']!.length, 1);
      expect(client.tables['products']!.length, 1);
      expect(client.tables['stock_movements']!.length, 1);
      expect(client.tables['quotations']!.length, 1);
      expect(client.tables['quotation_items']!.length, 1); // Preserved
    });

    test('3. Rerun creates no duplicates', () async {
      await seedSembast();

      // First run
      await service.migrate(dryRun: false);

      // Second run
      final report = await service.migrate(dryRun: false);
      expect(report.usersFound, 1);
      expect(report.usersSkipped, 1); // Skipped duplicate
      expect(report.usersInserted, 0);

      expect(report.productsSkipped, 1);
      expect(report.movementsSkipped, 1);
      expect(report.quotationsSkipped, 1);

      expect(client.tables['app_users']!.length, 1);
      expect(client.tables['products']!.length, 1);
    });

    test('4. Remote newer record preserved', () async {
      await seedSembast();

      // Seed remote with newer product
      client.tables['products']!.add({
        'id': 'P1',
        'updated_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });

      final report = await service.migrate(dryRun: false);
      expect(report.productsSkipped, 1); // Remote was newer, skipped update
      expect(client.tables['products']!.length, 1);
    });

    test('5. Partial failure can safely resume', () async {
      await seedSembast();

      // Force failure on the first insert (which is app_users)
      client.failNextInsert = true;

      final report1 = await service.migrate(dryRun: false);
      expect(report1.usersFailed, 1);
      expect(report1.usersInserted, 0);

      // Other tables should still migrate
      expect(report1.productsInserted, 1);
      expect(report1.movementsInserted, 1);
      expect(report1.quotationsInserted, 1);
      // Run again (failure flag cleared)
      final report2 = await service.migrate(dryRun: false);

      expect(report2.usersInserted, 1);
      expect(report2.usersFailed, 0);
      expect(report2.productsSkipped, 1);
      expect(report2.movementsSkipped, 1);
      expect(report2.quotationsSkipped, 1);
    });
  });
}
