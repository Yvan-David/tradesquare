import '../api/catalog_store.dart';

enum TradeSquareMockUserRole {
  businessOwner,
  buyer,
  supplier,
  administrator,
}

enum TradeSquareMockUserStatus {
  active,
  pending,
  inactive,
}

class TradeSquareMockUser {
  const TradeSquareMockUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.country,
    required this.city,
    required this.preferredLanguage,
    required this.role,
    required this.status,
    required this.businessAssociation,
    required this.joinDate,
    required this.profileCompleteness,
    this.photoUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String country;
  final String city;
  final String preferredLanguage;
  final TradeSquareMockUserRole role;
  final TradeSquareMockUserStatus status;
  final String businessAssociation;
  final DateTime joinDate;
  final int profileCompleteness;
  final String? photoUrl;

  factory TradeSquareMockUser.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      country: json['country'] as String? ?? '',
      city: json['city'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
      role: TradeSquareMockUserRole.values.firstWhere(
        (value) => value.name == json['role'],
        orElse: () => TradeSquareMockUserRole.businessOwner,
      ),
      status: TradeSquareMockUserStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TradeSquareMockUserStatus.active,
      ),
      businessAssociation: json['businessAssociation'] as String? ?? '',
      joinDate: json['joinDate'] is String
          ? DateTime.tryParse(json['joinDate'] as String) ??
              DateTime.utc(2025, 1, 1)
          : DateTime.utc(2025, 1, 1),
      profileCompleteness: (json['profileCompleteness'] as num?)?.toInt() ?? 0,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'country': country,
        'city': city,
        'preferredLanguage': preferredLanguage,
        'role': role.name,
        'status': status.name,
        'businessAssociation': businessAssociation,
        'joinDate': joinDate.toIso8601String(),
        'profileCompleteness': profileCompleteness,
        'photoUrl': photoUrl,
      };
}

List<TradeSquareMockUser> get tradeSquareMockUsers => CatalogStore.instance.users;
