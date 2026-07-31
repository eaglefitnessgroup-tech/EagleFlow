class CompanyProfile {
  final String brandName;
  final String name;
  final String licenseNo;
  final String trn;
  final String address;
  final String mobile;
  final String email;

  const CompanyProfile({
    required this.brandName,
    required this.name,
    required this.licenseNo,
    required this.trn,
    required this.address,
    required this.mobile,
    required this.email,
  });

  static const CompanyProfile defaultProfile = CompanyProfile(
    brandName: 'EAGLE FITNESS',
    name: 'MAX EAGLE FITNESS SPORT EQUIPMENT TRADING L.L.C',
    licenseNo: '982901',
    trn: '100456705100003',
    address:
        'NAWAL SALEH A ALRAJHI 3-59,\nHor Al Anz, Dubai,\nUnited Arab Emirates',
    mobile: '056 507 7088',
    email: 'sales@eaglefitnessgroup.com',
  );
}
