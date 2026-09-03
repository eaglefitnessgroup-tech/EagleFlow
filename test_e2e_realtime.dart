import 'dart:io' as import_io;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eagleflow/core/config/supabase_config.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/domain/product.dart';

void main() {
  testWidgets('E2E Realtime Test', (WidgetTester tester) async {
    await Supabase.initialize(
      url: 'https://pkpgbpzqauwksixxrlwm.supabase.co',
      anonKey: 'sb_publishable_8OutRAFjB6p83_OA2muE_w_qIg98V44',
    );

    final client = Supabase.instance.client;
    
    // Authenticate
    await client.auth.signInWithPassword(
      email: 'admin@eagleflow.com',
      password: 'password123',
    );
    
    await ServiceLocator().init();
    
    final repo = ServiceLocator().productRepository;

    print('Testing Realtime INSERT...');
    
    final testId = 'test-realtime-id-123';
    
    // Cleanup any previous run
    await client.from('products').delete().eq('id', testId);
    
    // Insert directly via REST (Simulating Device A)
    await client.from('products').insert({
      'id': testId,
      'product_code': 'TEST-RT-1',
      'name': 'Realtime Test Product',
      'category': 'Test',
      'brand': 'Test',
      'selling_price': 100,
      'opening_stock': 10,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Wait for Realtime event on Device B (our running app)
    await Future.delayed(Duration(seconds: 3));

    // Check Local Cache (Device B)
    final products = await repo.getAllProducts();
    final found = products.any((p) => p.id == testId);
    
    final f = import_io.File('results.txt');
    var out = 'Realtime INSERT: ${found ? 'PASS' : 'FAIL'}\n';

    // UPDATE
    await client.from('products').update({
      'name': 'Realtime Test Product Updated',
    }).eq('id', testId);

    await Future.delayed(Duration(seconds: 3));

    final updatedProduct = await repo.getProductById(testId);
    final updatePass = updatedProduct?.name == 'Realtime Test Product Updated';
    out += 'Realtime UPDATE: ${updatePass ? 'PASS' : 'FAIL'}\n';

    // DELETE (Soft delete via toggle or deleteProduct)
    // Our repo handles soft delete by checking active or deleted_at
    await client.from('products').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', testId);

    await Future.delayed(Duration(seconds: 3));

    final finalProducts = await repo.getAllProducts();
    final deletePass = !finalProducts.any((p) => p.id == testId);
    out += 'Realtime DELETE: ${deletePass ? 'PASS' : 'FAIL'}\n';
    
    // Cleanup
    await client.from('products').delete().eq('id', testId);

    out += 'Persistent business cache: NO\n';
    out += 'Offline queue: NO\n';
    f.writeAsStringSync(out);
    
    ServiceLocator().syncCoordinator.dispose();
    await client.dispose();
  });
}
