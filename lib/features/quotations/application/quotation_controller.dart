import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../domain/quotation.dart';
import '../domain/quotation_line_item.dart';
import '../domain/quotation_charges.dart';

class QuotationController extends ChangeNotifier {
  Quotation _quotation;

  QuotationController(this._quotation);

  Quotation get quotation => _quotation;

  void updateCustomerName(String name) {
    _quotation = _quotation.copyWith(
      customerInfo: _quotation.customerInfo.copyWith(name: name),
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
}
