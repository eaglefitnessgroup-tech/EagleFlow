import 'dart:async';

import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_controller.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_generation_issue.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  group('loading and mapping states', () {
    test(
      'starts loading and remains loading while products are pending',
      () async {
        final completer = Completer<List<Product>>();
        final fixture = QuickQuoteFixture(productCompleter: completer);
        final initialization = fixture.initialize();

        expect(fixture.controller.status, QuickQuoteControllerStatus.loading);

        completer.complete(fixture.products);
        await initialization;
        expect(fixture.controller.status, QuickQuoteControllerStatus.ready);
      },
    );

    test('reports mapping load failure', () async {
      final fixture = QuickQuoteFixture(
        refreshError: StateError('remote failed'),
        cachedError: StateError('cache failed'),
      );

      await fixture.initialize();

      expect(fixture.controller.status, QuickQuoteControllerStatus.error);
      expect(
        fixture.controller.errorMessage,
        contains('mappings are unavailable'),
      );
    });

    test('uses cached mappings when refresh fails', () async {
      final fixture = QuickQuoteFixture(refreshError: StateError('offline'));

      await fixture.initialize();

      expect(fixture.controller.status, QuickQuoteControllerStatus.ready);
      expect(fixture.controller.mappingNotice, contains('cached mappings'));
      expect(fixture.mappingRepository.refreshCalls, 1);
      expect(fixture.mappingRepository.cachedCalls, 1);
    });

    test('reports unavailable active automation configuration', () async {
      final fixture = QuickQuoteFixture(
        activeConfigurationError: const QuickQuoteActiveConfigUnavailableException(
          'Quick Quote automation configuration is not available. Please contact an administrator.',
        ),
      );

      await fixture.initialize();

      expect(fixture.controller.status, QuickQuoteControllerStatus.error);
      expect(
        fixture.controller.errorMessage,
        contains('contact an administrator'),
      );
    });

    test('surfaces last-known-good configuration cache fallback', () async {
      final fixture = QuickQuoteFixture(
        activeConfigurationSource: QuickQuoteActiveConfigSource.cache,
      );

      await fixture.initialize();

      expect(fixture.controller.status, QuickQuoteControllerStatus.ready);
      expect(
        fixture.controller.configurationNotice,
        contains('cached automation configuration'),
      );
    });
  });

  test('validates required, numeric, finite, and positive budgets', () {
    final controller = QuickQuoteFixture().controller;

    expect(controller.validateBudget(''), contains('required'));
    expect(controller.validateBudget('abc'), contains('valid numeric'));
    expect(controller.validateBudget('Infinity'), contains('valid numeric'));
    expect(controller.validateBudget('0'), contains('greater than zero'));
    expect(controller.validateBudget('-1'), contains('greater than zero'));
    expect(controller.validateBudget('250,000.50'), isNull);
  });

  test('only active mapped strength brands are available', () async {
    final products = buildCompleteProducts()
      ..add(
        testProduct(
          id: 'inactive-strength',
          name: 'Inactive Strength',
          code: 'INACTIVE',
          brand: 'Hidden Brand',
          isActive: false,
        ),
      )
      ..add(
        testProduct(
          id: 'unmapped-strength',
          name: 'Unmapped Strength',
          code: 'UNMAPPED',
          brand: 'Unmapped Brand',
        ),
      );
    final mappings = buildCompleteMappings()
      ..add(
        testMapping(
          productId: 'inactive-strength',
          section: QuickQuoteSection.strength,
          roleKey: 'strength_machine',
          strengthArea: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: 'inactive',
        ),
      );
    final fixture = QuickQuoteFixture(products: products, mappings: mappings);

    await fixture.initialize();

    expect(fixture.controller.strengthBrands, ['Premier', 'Matrix']);
  });

  test(
    'cardio defaults are deterministic and exclude unapproved options',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();

      expect(
        fixture.controller.selectedCardioProductId(
          QuickQuoteCardioRole.treadmill,
        ),
        'cardio-treadmill',
      );
      final visibleIds = QuickQuoteCardioRole.values
          .expand(fixture.controller.cardioCandidates)
          .map((product) => product.id);
      expect(visibleIds, isNot(contains('cardio-rower')));
      expect(visibleIds, isNot(contains('cardio-home')));
    },
  );

  test(
    'availability preserves independent pin and plate information',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();

      for (final area in QuickQuoteStrengthArea.values) {
        expect(
          fixture.controller.hasStrengthCandidate(
            area,
            QuickQuoteLoadType.pinLoaded,
          ),
          isTrue,
        );
        expect(
          fixture.controller.hasStrengthCandidate(
            area,
            QuickQuoteLoadType.plateLoaded,
          ),
          isTrue,
        );
      }
      expect(fixture.controller.hasDumbbellFullSetBundle, isTrue);
      expect(fixture.controller.hasCompleteWeightPlateFamily, isTrue);
      expect(
        fixture.controller.hasMultifunctionCandidate(
          QuickQuoteMultifunctionRole.functionalTrainer,
        ),
        isTrue,
      );
    },
  );

  test(
    'generate uses the current brand, series, cardio, and VAT-inclusive budget',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();
      fixture.controller
        ..selectPremierPinSeries('PXN')
        ..selectPremierPlateSeries('PXL')
        ..selectCardioProduct(
          QuickQuoteCardioRole.treadmill,
          'cardio-treadmill-alt',
        );

      final generated = await fixture.controller.generate('100000');

      // PXN/PXL are valid selections but unavailable in this fixture, so the
      // controller must block an under-covered result while retaining selections.
      expect(generated, isFalse);
      expect(fixture.controller.lastRequest, isNull);
      expect(
        fixture.controller.generationError,
        contains('cannot be resolved'),
      );

      fixture.controller
        ..selectPremierPinSeries('APN')
        ..selectPremierPlateSeries('APL');
      expect(await fixture.controller.generate('100000'), isTrue);
      final request = fixture.controller.lastRequest!;
      expect(request.strengthBrand, 'Premier');
      expect(request.premierPinSeriesPrefix, 'APN');
      expect(request.premierPlateSeriesPrefix, 'APL');
      expect(request.vatBudgetMode, QuickQuoteVatBudgetMode.includingVat);
      expect(
        request.cardioSelections[QuickQuoteCardioRole.treadmill]!.productId,
        'cardio-treadmill-alt',
      );
    },
  );

  test(
    'inactive configured cardio blocks generation with a clear error',
    () async {
      final products = buildCompleteProducts();
      products.removeWhere((product) => product.id == 'cardio-spinning_bike');
      products.add(
        testProduct(
          id: 'cardio-spinning_bike',
          name: 'Commercial Spinning Bike',
          code: 'C-4',
          brand: 'Cardio Pro',
          category: 'Commercial Cardio',
          isActive: false,
        ),
      );
      final fixture = QuickQuoteFixture(products: products);
      await fixture.initialize();

      expect(await fixture.controller.generate('100000'), isFalse);
      expect(fixture.controller.generationError, contains('inactive'));
      expect(
        fixture.controller.generationIssue?.type,
        QuickQuoteGenerationIssueType.inactiveConfiguredProduct,
      );
      expect(fixture.controller.result, isNull);
    },
  );

  test(
    'unsupported budget is rejected without guessing another profile',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();

      expect(await fixture.controller.generate('1'), isFalse);
      expect(fixture.controller.result, isNull);
      expect(fixture.controller.generationError, contains('not supported'));
      expect(fixture.controller.generationError, contains('100K–500K'));
      expect(
        fixture.controller.generationIssue?.type,
        QuickQuoteGenerationIssueType.unsupportedBudget,
      );
    },
  );

  test(
    'generation produces an in-memory result and has no save dependency',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();

      expect(await fixture.controller.generate('100000'), isTrue);
      expect(fixture.controller.result, isNotNull);
      expect(fixture.controller.result!.selections, isNotEmpty);
      expect(fixture.controller.runtimeType.toString(), 'QuickQuoteController');
    },
  );
}
