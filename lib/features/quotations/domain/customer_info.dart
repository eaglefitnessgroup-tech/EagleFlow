class CustomerInfo {
  final String name;
  final String company;
  final String phone;
  final String email;
  final String projectLocation;

  const CustomerInfo({
    required this.name,
    this.company = '',
    this.phone = '',
    this.email = '',
    this.projectLocation = '',
  });

  CustomerInfo copyWith({
    String? name,
    String? company,
    String? phone,
    String? email,
    String? projectLocation,
  }) {
    return CustomerInfo(
      name: name ?? this.name,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      projectLocation: projectLocation ?? this.projectLocation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'company': company,
      'phone': phone,
      'email': email,
      'projectLocation': projectLocation,
    };
  }

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      projectLocation: json['projectLocation'] as String? ?? '',
    );
  }
}
