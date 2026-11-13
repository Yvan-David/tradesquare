import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/domain/trade_square_auth_session.dart';

/// Signed-in writes against Supabase (RLS uses the user session).
class MemberMarketplace {
  MemberMarketplace({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> ensureListed(TradeSquareAuthUser user) async {
    if (user.businessId != null && user.businessId!.isNotEmpty) {
      return user.businessId!;
    }

    final profile = await _client
        .from('profiles')
        .select('id, business_id, full_name, email, phone, country, city')
        .eq('auth_user_id', user.authUserId)
        .maybeSingle();

    final existing = profile?['business_id'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final profileId = (profile?['id'] as String?) ?? user.profileId;
    if (profileId.isEmpty) {
      throw const AuthException(
        'Your profile is not ready yet. Confirm your email, then sign in again.',
      );
    }

    final businessId = 'biz_${profileId.replaceFirst('usr_', '')}';
    final name = ((profile?['full_name'] as String?) ?? user.fullName).trim();
    await _client.from('businesses').upsert({
      'id': businessId,
      'name': name.isEmpty ? 'TradeSquare member' : name,
      'description': 'New TradeSquare member',
      'industry': 'General',
      'category': 'General',
      'country': (profile?['country'] as String?)?.trim().isNotEmpty == true
          ? profile!['country']
          : 'Rwanda',
      'city': (profile?['city'] as String?)?.trim().isNotEmpty == true
          ? profile!['city']
          : 'Kigali',
      'email': (profile?['email'] as String?) ?? user.email,
      'phone': (profile?['phone'] as String?) ?? user.phone,
      'owner_id': profileId,
      'verification_status': 'not_submitted',
      'profile_completeness': 40,
    });
    await _client.from('profiles').update({
      'business_id': businessId,
      'status': 'active',
    }).eq('id', profileId);
    return businessId;
  }

  Future<Map<String, dynamic>> createBuyingRequest({
    required String buyerBusinessId,
    required String productOrService,
    required String description,
    required String category,
    required int requiredQuantity,
    required String unit,
    required String deliveryDestination,
    required String urgency,
  }) async {
    final id = 'req_${DateTime.now().millisecondsSinceEpoch}';
    final row = await _client.from('buying_requests').insert({
      'id': id,
      'buyer_business_id': buyerBusinessId,
      'product_or_service': productOrService,
      'description': description,
      'category': category.isEmpty ? 'General' : category,
      'required_quantity': requiredQuantity,
      'unit': unit.isEmpty ? 'unit' : unit,
      'delivery_destination': deliveryDestination,
      'urgency': urgency,
      'status': 'Open',
      'currency': 'USD',
    }).select().single();
    return {
      'id': row['id'],
      'buyerBusinessId': row['buyer_business_id'],
      'productOrService': row['product_or_service'],
      'description': row['description'] ?? '',
      'category': row['category'] ?? '',
      'requiredQuantity': row['required_quantity'] ?? 0,
      'unit': row['unit'] ?? 'unit',
      'targetPriceRange': row['target_price_range'] ?? '',
      'currency': row['currency'] ?? 'USD',
      'deliveryDestination': row['delivery_destination'] ?? '',
      'preferredSupplierLocation': row['preferred_supplier_location'] ?? '',
      'deadline': row['deadline'],
      'urgency': row['urgency'] ?? urgency,
      'status': row['status'] ?? 'Open',
      'publishedAt': row['published_at'] ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> requestConnection({
    required String fromBusinessId,
    required String toBusinessId,
  }) async {
    final id = 'conn_${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('business_connections').insert({
      'id': id,
      'requesting_business_id': fromBusinessId,
      'receiving_business_id': toBusinessId,
      'status': 'pending',
      'relationship_type': 'partner',
      'introductory_message': 'I would like to connect on TradeSquare.',
    });
  }
}
