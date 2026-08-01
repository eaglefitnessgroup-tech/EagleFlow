class CompanyProfile {
  final String brandName;
  final String tagline;
  final String website;
  final String licenseNumber;
  final String legalName;
  final String addressLine1;
  final String addressLine2;
  final String mobile;
  final String telephone;
  final String trn;

  const CompanyProfile({
    required this.brandName,
    required this.tagline,
    required this.website,
    required this.licenseNumber,
    required this.legalName,
    required this.addressLine1,
    required this.addressLine2,
    required this.mobile,
    required this.telephone,
    required this.trn,
  });

  static const CompanyProfile defaultProfile = CompanyProfile(
    brandName: 'MAX EAGLE FITNESS',
    tagline: 'THE COMPLETE GYM SOLUTION',
    website: 'eaglefitnessgroup.com',
    licenseNumber: '982901',
    legalName: 'MAX EAGLE FITNESS SPORT EQUIPMENT TRADING LLC',
    addressLine1: 'SH03, INDUSTRIAL AREA 18',
    addressLine2: 'MALEHA ROAD, SHARJAH, UNITED ARAB EMIRATES',
    mobile: '+971 56 507 7088',
    telephone: '056 507 7088', // Keeping previously approved temp value
    trn: '100456705100003',
  );
}
