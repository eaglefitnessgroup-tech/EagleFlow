import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../domain/quotation.dart';
import '../domain/quotation_line_item.dart';
import '../domain/quotation_charges.dart';
import '../domain/quotation_status.dart';
import '../data/quotation_repository.dart';
import '../../products/domain/product.dart';

class QuotationController extends ChangeNotifier {
  Quotation _quotation;
  String? _revisionSourceQuotationId;

  QuotationController(this._quotation, {this._revisionSourceQuotationId});

  factory QuotationController.forRevision(Quotation source) {
    if (source.id.isEmpty) {
      throw ArgumentError(
        'A saved quotation is required to create a revision.',
      );
    }

    final now = DateTime.now();
    final baseQuotationId = source.baseQuotationId ?? source.id;
    final copiedItems = source.lineItems.indexed.map((entry) {
      final index = entry.$1;
      final item = entry.$2;
      return item.copyWith(
        id: 'revision-draft-$index-${item.id}',
        imageBytes: item.imageBytes == null
            ? null
            : Uint8List.fromList(item.imageBytes!),
      );
    }).toList();

    final draft = source.copyWith(
      id: '',
      baseQuotationId: baseQuotationId,
      revisionNo: source.revisionNo + 1,
      customerInfo: source.customerInfo.copyWith(),
      charges: source.charges.copyWith(),
      lineItems: copiedItems,
      status: QuotationStatus.draft,
      createdDate: now,
      modifiedDate: now,
    );

    return QuotationController(draft, revisionSourceQuotationId: source.id);
  }

  Quotation get quotation => _quotation;
  bool get isRevisionDraft => _revisionSourceQuotationId != null;
  String? get revisionSourceQuotationId => _revisionSourceQuotationId;

  void loadQuotation(Quotation newQuotation) {
    _quotation = newQuotation;
    notifyListeners();
  }

  Future<Quotation> save(QuotationRepository repository) async {
    final sourceQuotationId = _revisionSourceQuotationId;
    final savedQuotation = sourceQuotationId == null
        ? await repository.saveQuotation(_quotation)
        : await repository.createRevision(sourceQuotationId, _quotation);
    _revisionSourceQuotationId = null;
    loadQuotation(savedQuotation);
    return savedQuotation;
  }

  void updateCustomerName(String name) {
    _quotation = _quotation.copyWith(
      customerInfo: _quotation.customerInfo.copyWith(name: name),
    );
    notifyListeners();
  }

  void updateCustomerDetails({
    String? company,
    String? phone,
    String? email,
    String? projectLocation,
  }) {
    _quotation = _quotation.copyWith(
      customerInfo: _quotation.customerInfo.copyWith(
        company: company,
        phone: phone,
        email: email,
        projectLocation: projectLocation,
      ),
    );
    notifyListeners();
  }

  void updateNotes({String? customerNotes, String? internalNotes}) {
    _quotation = _quotation.copyWith(
      customerNotes: customerNotes ?? _quotation.customerNotes,
      internalNotes: internalNotes ?? _quotation.internalNotes,
    );
    notifyListeners();
  }

  void updateQuantity(String itemId, int qty) {
    final newQty = math.max(1, qty); // Quantity minimum 1
    _updateLineItem(itemId, (item) => item.copyWith(quantity: newQty));
  }

  void updateUnitPrice(String itemId, double price) {
    final newPrice = math.max(0.0, price);
    _updateLineItem(itemId, (item) => item.copyWith(unitPrice: newPrice));
  }

  void updateLineDiscount(String itemId, double discountPercent) {
    final newDiscount = discountPercent.clamp(0.0, 100.0);
    _updateLineItem(itemId, (item) => item.copyWith(discount: newDiscount));
  }

  void removeItem(String itemId) {
    final newItems = _quotation.lineItems.where((i) => i.id != itemId).toList();
    _quotation = _quotation.copyWith(lineItems: newItems);
    notifyListeners();
  }

  void reorderLineItem(int oldIndex, int newIndex) {
    final itemCount = _quotation.lineItems.length;
    if (oldIndex < 0 ||
        oldIndex >= itemCount ||
        newIndex < 0 ||
        newIndex > itemCount) {
      return;
    }

    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex == oldIndex ||
        adjustedNewIndex < 0 ||
        adjustedNewIndex >= itemCount) {
      return;
    }

    final newItems = List<QuotationLineItem>.from(_quotation.lineItems);
    final item = newItems.removeAt(oldIndex);
    newItems.insert(adjustedNewIndex, item);

    _quotation = _quotation.copyWith(lineItems: newItems);
    notifyListeners();
  }

  void updateCharges({
    double? delivery,
    double? installation,
    double? other,
    double? discount,
    double? vat,
  }) {
    QuotationCharges charges = _quotation.charges;
    if (delivery != null) {
      charges = charges.copyWith(deliveryCharges: math.max(0.0, delivery));
    }
    if (installation != null) {
      charges = charges.copyWith(
        installationCharges: math.max(0.0, installation),
      );
    }
    if (other != null) {
      charges = charges.copyWith(otherCharges: math.max(0.0, other));
    }
    if (discount != null) {
      charges = charges.copyWith(overallDiscount: math.max(0.0, discount));
    }
    if (vat != null) {
      charges = charges.copyWith(vatPercentage: math.max(0.0, vat));
    }

    _quotation = _quotation.copyWith(charges: charges);
    notifyListeners();
  }

  void _updateLineItem(
    String itemId,
    QuotationLineItem Function(QuotationLineItem) updater,
  ) {
    final index = _quotation.lineItems.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final newItems = List<QuotationLineItem>.from(_quotation.lineItems);
    newItems[index] = updater(newItems[index]);

    _quotation = _quotation.copyWith(lineItems: newItems);
    notifyListeners();
  }

  bool containsProduct(String productId) {
    return _quotation.lineItems.any((item) => item.productId == productId);
  }

  void incrementExistingProduct(String productId, {int by = 1}) {
    final index = _quotation.lineItems.indexWhere(
      (i) => i.productId == productId,
    );
    if (index == -1) return;

    final newQty = math.max<int>(
      1,
      _quotation.lineItems[index].quantity + math.max<int>(1, by),
    );
    _updateLineItem(
      _quotation.lineItems[index].id,
      (item) => item.copyWith(quantity: newQty),
    );
  }

  void addProduct(Product product, {int quantity = 1}) {
    if (containsProduct(product.id)) {
      incrementExistingProduct(product.id, by: quantity);
      return;
    }

    final String uniqueId =
        '${DateTime.now().millisecondsSinceEpoch}_${product.id}';
    final int safeQty = math.max<int>(1, quantity);

    final newItem = QuotationLineItem(
      id: uniqueId,
      productId: product.id,
      productCode: product.productCode,
      name: product.name,
      brand: product.brand,
      condition: product.condition,
      unitPrice: product.sellingPrice,
      quantity: safeQty,
      discount: 0.0,
      imageId: product.imageId,
      imageBytes: product.imageBytes,
      description: product.description,
      isCustom: false,
      isVatApplicable: product.isVatApplicable,
    );

    _quotation = _quotation.copyWith(
      lineItems: [..._quotation.lineItems, newItem],
    );
    notifyListeners();
  }

  void addCustomItem(QuotationLineItem item) {
    // Generate a unique ID if not provided, or just append the item
    final String uniqueId = item.id.isNotEmpty
        ? item.id
        : '${DateTime.now().millisecondsSinceEpoch}_custom';

    final newItem = item.copyWith(id: uniqueId, isCustom: true);

    _quotation = _quotation.copyWith(
      lineItems: [..._quotation.lineItems, newItem],
    );
    notifyListeners();
  }

  void updateCustomItem(String itemId, QuotationLineItem updatedItem) {
    _updateLineItem(itemId, (existing) {
      // Preserve imageBytes if the updated item does not specify a new one
      // Wait, if the user explicitly removed the image, we need a way to clear it.
      // We will assume the updatedItem has the exact intended state.
      return updatedItem;
    });
  }

  void addProducts(List<Product> products, {int quantity = 1}) {
    if (products.isEmpty) return;

    final newItemsList = List<QuotationLineItem>.from(_quotation.lineItems);
    final safeQty = math.max<int>(1, quantity);

    for (final product in products) {
      final index = newItemsList.indexWhere((i) => i.productId == product.id);

      if (index != -1) {
        // Increment duplicate
        final existingItem = newItemsList[index];
        newItemsList[index] = existingItem.copyWith(
          quantity: existingItem.quantity + safeQty,
        );
      } else {
        // Create new
        final String uniqueId =
            '${DateTime.now().millisecondsSinceEpoch}_${product.id}';
        final newItem = QuotationLineItem(
          id: uniqueId,
          productId: product.id,
          productCode: product.productCode,
          name: product.name,
          brand: product.brand,
          condition: product.condition,
          unitPrice: product.sellingPrice,
          quantity: safeQty,
          discount: 0.0,
          imageId: product.imageId,
          imageBytes: product.imageBytes,
          description: product.description,
          isCustom: false,
          isVatApplicable: product.isVatApplicable,
        );
        newItemsList.add(newItem);
      }
    }

    _quotation = _quotation.copyWith(lineItems: newItemsList);
    notifyListeners();
  }
}
