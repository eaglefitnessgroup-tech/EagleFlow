class QuotationCharges {
  final double deliveryCharges;
  final double installationCharges;
  final double otherCharges;
  final double overallDiscount;
  final double vatPercentage;

  const QuotationCharges({
    this.deliveryCharges = 0.0,
    this.installationCharges = 0.0,
    this.otherCharges = 0.0,
    this.overallDiscount = 0.0,
    this.vatPercentage = 5.0, // Default VAT for UAE
  });

  QuotationCharges copyWith({
    double? deliveryCharges,
    double? installationCharges,
    double? otherCharges,
    double? overallDiscount,
    double? vatPercentage,
  }) {
    return QuotationCharges(
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      installationCharges: installationCharges ?? this.installationCharges,
      otherCharges: otherCharges ?? this.otherCharges,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      vatPercentage: vatPercentage ?? this.vatPercentage,
    );
  }
}
