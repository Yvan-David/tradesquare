import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/trade_square_auth_models.dart';
import '../domain/trade_square_auth_session.dart';

abstract class TradeSquareAuthRepository {
  Future<TradeSquareAuthUser?> restoreSession();
  Future<TradeSquareAuthUser> signIn({
    required String email,
    required String password,
  });
  Future<TradeSquareAuthUser> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    TradeSquareAccountRole intent = TradeSquareAccountRole.both,
  });
  Future<void> signOut();
  Future<TradeSquareAuthUser> updateAccountIntent(TradeSquareAccountRole role);
  Stream<AuthState> get authStateChanges;
}

class SupabaseAuthRepository implements TradeSquareAuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<TradeSquareAuthUser?> restoreSession() async {
    final session = _client.auth.currentSession;
    final user = session?.user ?? _client.auth.currentUser;
    if (user == null) return null;
    return _loadProfile(user);
  }

  @override
  Future<TradeSquareAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-in failed. Check your email and password.');
    }
    return _loadProfile(user);
  }

  @override
  Future<TradeSquareAuthUser> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    TradeSquareAccountRole intent = TradeSquareAccountRole.both,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'account_intent': tradeSquareAccountIntentSql(intent),
      },
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Could not create the account.');
    }
    // Email confirmation may leave session null — still return a provisional user.
    if (response.session == null) {
      return TradeSquareAuthUser(
        authUserId: user.id,
        profileId: '',
        email: email.trim(),
        fullName: fullName.trim(),
        role: intent,
        phone: phone.trim(),
      );
    }
    return _loadProfile(user);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<TradeSquareAuthUser> updateAccountIntent(
    TradeSquareAccountRole role,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in.');
    }
    await _client.from('profiles').update({
      'account_intent': tradeSquareAccountIntentSql(role),
      'role': tradeSquareDbRoleSql(role),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('auth_user_id', user.id);
    return _loadProfile(user);
  }

  Future<TradeSquareAuthUser> _loadProfile(User user) async {
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();
    } catch (_) {
      row = null;
    }

    if (row == null) {
      try {
        row = await _client
            .from('profiles')
            .select()
            .eq('email', user.email ?? '')
            .maybeSingle();
        if (row != null && row['auth_user_id'] == null) {
          await _client.from('profiles').update({
            'auth_user_id': user.id,
          }).eq('id', row['id']);
        }
      } catch (_) {
        row = null;
      }
    }

    if (row == null) {
      final meta = user.userMetadata ?? const <String, dynamic>{};
      return TradeSquareAuthUser(
        authUserId: user.id,
        profileId: '',
        email: user.email ?? '',
        fullName: (meta['full_name'] as String?)?.trim().isNotEmpty == true
            ? meta['full_name'] as String
            : (user.email?.split('@').first ?? 'Member'),
        role: tradeSquareRoleFromProfile(
          dbRole: 'business_owner',
          accountIntent: meta['account_intent'] as String?,
        ),
        phone: (meta['phone'] as String?) ?? '',
      );
    }

    return TradeSquareAuthUser(
      authUserId: user.id,
      profileId: row['id'] as String? ?? '',
      email: row['email'] as String? ?? user.email ?? '',
      fullName: row['full_name'] as String? ??
          user.email?.split('@').first ??
          'Member',
      role: tradeSquareRoleFromProfile(
        dbRole: row['role'] as String? ?? 'business_owner',
        accountIntent: row['account_intent'] as String?,
      ),
      phone: row['phone'] as String? ?? '',
      businessId: row['business_id'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }
}

/// In-memory auth for widget tests (no network).
class FakeTradeSquareAuthRepository implements TradeSquareAuthRepository {
  FakeTradeSquareAuthRepository({
    this.signedInUser,
    this.failSignIn = false,
    this.defaultRole = TradeSquareAccountRole.both,
  });

  TradeSquareAuthUser? signedInUser;
  final bool failSignIn;
  final TradeSquareAccountRole defaultRole;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<TradeSquareAuthUser?> restoreSession() async => signedInUser;

  @override
  Future<TradeSquareAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (failSignIn) {
      throw const AuthException('Invalid login credentials');
    }
    signedInUser = TradeSquareAuthUser(
      authUserId: 'auth_test',
      profileId: 'usr_test',
      email: email.trim(),
      fullName: email.split('@').first,
      role: defaultRole,
    );
    return signedInUser!;
  }

  @override
  Future<TradeSquareAuthUser> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    TradeSquareAccountRole intent = TradeSquareAccountRole.both,
  }) async {
    signedInUser = TradeSquareAuthUser(
      authUserId: 'auth_new',
      profileId: 'usr_new',
      email: email.trim(),
      fullName: fullName.trim(),
      role: intent,
      phone: phone,
    );
    return signedInUser!;
  }

  @override
  Future<void> signOut() async {
    signedInUser = null;
  }

  @override
  Future<TradeSquareAuthUser> updateAccountIntent(
    TradeSquareAccountRole role,
  ) async {
    final current = signedInUser;
    if (current == null) throw const AuthException('Not signed in.');
    signedInUser = current.copyWith(role: role);
    return signedInUser!;
  }
}
