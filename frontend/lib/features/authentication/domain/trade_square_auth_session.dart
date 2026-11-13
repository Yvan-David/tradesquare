import 'trade_square_auth_models.dart';

class TradeSquareAuthUser {
  const TradeSquareAuthUser({
    required this.authUserId,
    required this.profileId,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.businessId,
    this.photoUrl,
  });

  final String authUserId;
  final String profileId;
  final String email;
  final String fullName;
  final TradeSquareAccountRole role;
  final String phone;
  final String? businessId;
  final String? photoUrl;

  TradeSquareAuthUser copyWith({
    TradeSquareAccountRole? role,
    String? fullName,
    String? phone,
    String? businessId,
    String? photoUrl,
  }) {
    return TradeSquareAuthUser(
      authUserId: authUserId,
      profileId: profileId,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      businessId: businessId ?? this.businessId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

TradeSquareAccountRole tradeSquareRoleFromProfile({
  required String dbRole,
  String? accountIntent,
}) {
  final intent = (accountIntent ?? '').toLowerCase();
  if (intent == 'buyer') return TradeSquareAccountRole.buyer;
  if (intent == 'supplier') return TradeSquareAccountRole.supplier;
  if (intent == 'both') return TradeSquareAccountRole.both;

  switch (dbRole) {
    case 'buyer':
      return TradeSquareAccountRole.buyer;
    case 'supplier':
      return TradeSquareAccountRole.supplier;
    case 'administrator':
    case 'business_owner':
    default:
      return TradeSquareAccountRole.both;
  }
}

String tradeSquareAccountIntentSql(TradeSquareAccountRole role) {
  return switch (role) {
    TradeSquareAccountRole.buyer => 'buyer',
    TradeSquareAccountRole.supplier => 'supplier',
    TradeSquareAccountRole.both => 'both',
  };
}

String tradeSquareDbRoleSql(TradeSquareAccountRole role) {
  return switch (role) {
    TradeSquareAccountRole.buyer => 'buyer',
    TradeSquareAccountRole.supplier => 'supplier',
    TradeSquareAccountRole.both => 'business_owner',
  };
}
