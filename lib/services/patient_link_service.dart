import 'package:supabase_flutter/supabase_flutter.dart';

class PatientLinkResult {
  final String status;
  final String? patientId;
  final String? inviteCode;
  final String? message;

  const PatientLinkResult({
    required this.status,
    this.patientId,
    this.inviteCode,
    this.message,
  });

  bool get isLinked => status == 'linked';
  bool get isInvited => status == 'invited';
}

class PatientLinkService {
  final SupabaseClient _client;

  PatientLinkService(this._client);

  /// Links an existing patient account or creates a pending email invite.
  Future<PatientLinkResult> linkByEmail({
    required String email,
    String? lovedOneName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Email is required');
    }

    try {
      final response = await _client.rpc(
        'link_patient_by_email',
        params: {
          'p_email': normalized,
          'p_name': lovedOneName?.trim().isEmpty == true ? null : lovedOneName?.trim(),
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      return PatientLinkResult(
        status: map['status'] as String? ?? 'unknown',
        patientId: map['patient_id'] as String?,
        inviteCode: map['invite_code'] as String?,
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.message.contains('link_patient_by_email')) {
        return _linkByEmailFallback(normalized, lovedOneName);
      }
      rethrow;
    }
  }

  Future<PatientLinkResult> _linkByEmailFallback(
    String email,
    String? lovedOneName,
  ) async {
    final caregiverId = _client.auth.currentUser?.id;
    if (caregiverId == null) throw Exception('Not signed in');

    final patientRow = await _client
        .from('users')
        .select('id')
        .eq('email', email)
        .eq('role', 'patient')
        .maybeSingle();

    if (patientRow != null) {
      final patientId = patientRow['id'] as String;
      await _client.from('caregiver_patient_mapping').upsert({
        'caregiver_id': caregiverId,
        'patient_id': patientId,
      });
      return PatientLinkResult(status: 'linked', patientId: patientId);
    }

    final invite = await _client
        .from('care_invites')
        .upsert({
          'caregiver_id': caregiverId,
          'patient_email': email,
          'patient_name': lovedOneName,
          'status': 'pending',
        })
        .select('invite_code')
        .single();

    return PatientLinkResult(
      status: 'invited',
      inviteCode: invite['invite_code'] as String?,
      message: 'Run supabase_care_invites.sql in Supabase for full invite support.',
    );
  }

  static Future<int> acceptPendingInvites(SupabaseClient client) async {
    try {
      final count = await client.rpc('accept_pending_care_invites');
      return (count as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
