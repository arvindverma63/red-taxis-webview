class CustomerUser {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final bool isGuest;

  const CustomerUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    this.isGuest = false,
  });

  factory CustomerUser.guest() {
    return const CustomerUser(
      id: 'guest',
      email: 'guest@redtaxi.co.uk',
      fullName: 'Guest Customer',
      phone: '',
      isGuest: true,
    );
  }

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    return CustomerUser(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      phone: json['phone'] ?? json['telephone'] ?? '',
      isGuest: json['isGuest'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phone': phone,
    'isGuest': isGuest,
  };
}
