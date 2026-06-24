import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes the signed-in user's row in public.users.
class UserProfileService {
  UserProfileService(this._client);

  final SupabaseClient _client;

  /// Uses get_my_profile RPC first — avoids broken RLS on direct SELECT.
  Future<Map<String, dynamic>?> fetch(String userId) async {
    final sessionId = _client.auth.currentSession?.user.id;
    if (sessionId == null) return null;

    // TEMPORARILY DISABLE RPC
    /*
    try {
      final data = await _client.rpc('get_my_profile');
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    */

    try {
      final row = await _client
          .from('users')
          .select(
            'id, name, role, email, account_status, verification_status, verification_requested_at, verification_completed_at, verification_rejected_reason',
          )
          .eq('id', userId)
          .maybeSingle();
          print('PROFILE DATA: $row');
      return row;
    } catch (e) {
      throw Exception('Could not load profile: $e');
    }
  }

  Future<void> save({
    required String userId,
    required String name,
    required String role,
    required String email,
  }) async {
    try {
      await _client.rpc('ensure_user_profile', params: {
        'p_name': name,
        'p_role': role,
        'p_email': email,
      });
    } catch (e) {
      throw Exception(
        'Profile save failed: $e\n\n'
        'Run supabase_users_rls_fix.sql in Supabase SQL Editor.',
      );
    }

    Map<String, dynamic>? saved;
    try {
      saved = await fetch(userId);
    } catch (_) {
      // Save succeeded via RPC; profile read will work on next screen load.
      saved = {
        'id': userId,
        'name': name,
        'role': role,
        'email': email.trim().toLowerCase(),
      };
    }

    if (saved == null) {
      throw Exception(
        'Profile save failed. Run supabase_users_rls_fix.sql in Supabase.',
      );
    }
  }
}
