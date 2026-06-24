import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for admin to manage verification requests
class AdminVerificationService {
  AdminVerificationService(this._client);

  final SupabaseClient _client;

  /// Get all pending verification requests
  Future<List<Map<String, dynamic>>> getPendingVerifications({
    String? role,
  }) async {
    try {
      var query = _client.from('user_verification_requests').select(
            '*, users:user_id(id, name, email, role, created_at)',
          ).eq('status', 'pending');

      if (role != null) {
        query = query.eq('role', role);
      }

      final results = await query.order('submitted_at', ascending: true);
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to get pending verifications: $e');
    }
  }

  /// Get all verification requests (paginated)
  Future<List<Map<String, dynamic>>> getAllVerifications({
    int page = 0,
    int pageSize = 20,
    String? status,
    String? role,
  }) async {
    try {
      var query = _client.from('user_verification_requests').select(
            '*, users:user_id(id, name, email, role)',
          );

      if (status != null) {
        query = query.eq('status', status);
      }
      if (role != null) {
        query = query.eq('role', role);
      }

      final results = await query
          .order('submitted_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to get verifications: $e');
    }
  }

  /// Get verification metrics for admin dashboard
  Future<Map<String, dynamic>> getVerificationMetrics() async {
    try {
      final pending =
          await _client.from('user_verification_requests').select().eq('status', 'pending');
      final approved =
          await _client.from('user_verification_requests').select().eq('status', 'approved');
      final rejected =
          await _client.from('user_verification_requests').select().eq('status', 'rejected');

      final pendingDoctors = (pending as List)
          .where((r) => r['role'] == 'doctor')
          .length;
      final pendingCaregivers = (pending as List)
          .where((r) => r['role'] == 'caregiver')
          .length;

      return {
        'total_pending': pending.length,
        'total_approved': approved.length,
        'total_rejected': rejected.length,
        'pending_doctors': pendingDoctors,
        'pending_caregivers': pendingCaregivers,
      };
    } catch (e) {
      throw Exception('Failed to get verification metrics: $e');
    }
  }

  /// Get all pending users (accounts in PENDING status)
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      final results = await _client
          .from('users')
          .select()
          .eq('account_status', 'PENDING')
          .order('created_at', ascending: true);

      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to get pending users: $e');
    }
  }

  /// Manually activate a user account (admin override)
  Future<void> activateUserAccount(String userId) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }

      await _client.from('users').update({
        'account_status': 'ACTIVE',
        'verification_status': 'VERIFIED',
        'verification_completed_at': DateTime.now().toIso8601String(),
        'verified_by': adminId,
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to activate user: $e');
    }
  }

  /// Suspend a user account
  Future<void> suspendUserAccount(String userId, String reason) async {
    try {
      await _client.from('users').update({
        'account_status': 'SUSPENDED',
        'verification_rejected_reason': reason,
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to suspend user: $e');
    }
  }

  /// Get doctor credentials for admin review
  Future<Map<String, dynamic>?> getDoctorCredentialsForReview(
      String userId) async {
    try {
      final creds = await _client
          .from('doctor_credentials')
          .select(
              '*, users:user_id(id, name, email, created_at, verification_status)')
          .eq('user_id', userId)
          .maybeSingle();

      return creds;
    } catch (e) {
      throw Exception('Failed to fetch doctor credentials: $e');
    }
  }

  /// Get caregiver verification for admin review
  Future<Map<String, dynamic>?> getCaregiverVerificationForReview(
      String userId) async {
    try {
      final verif = await _client
          .from('caregiver_verification')
          .select(
              '*, users:user_id(id, name, email, created_at, verification_status)')
          .eq('user_id', userId)
          .maybeSingle();

      return verif;
    } catch (e) {
      throw Exception('Failed to fetch caregiver verification: $e');
    }
  }

  /// Log audit entry for admin actions
  Future<void> _logAuditEntry({
    required String action,
    required String adminUserId,
    String? targetUserId,
    String? targetRole,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'action': action,
        'admin_user_id': adminUserId,
        'target_user_id': targetUserId,
        'target_role': targetRole,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details ?? {},
      });
    } catch (e) {
      // Log error but don't throw to avoid blocking main operation
      print('Failed to log audit entry: $e');
    }
  }

  /// Approve doctor verification with audit logging
  Future<void> approveDoctorVerification({
    required String verificationRequestId,
    required String userId,
    String? adminNotes,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }

      // Get user role for audit log
      final user = await _client.from('users').select('role').eq('id', userId).maybeSingle();
      final targetRole = user?['role'] as String?;

      // Update verification request
      await _client.from('user_verification_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': adminId,
        'admin_notes': adminNotes,
      }).eq('id', verificationRequestId);

      // Update user status
      await _client.from('users').update({
        'verification_status': 'VERIFIED',
        'account_status': 'ACTIVE',
        'verification_completed_at': DateTime.now().toIso8601String(),
        'verified_by': adminId,
      }).eq('id', userId);

      // Update doctor credentials as verified
      await _client.from('doctor_credentials').update({
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Log audit entry
      await _logAuditEntry(
        action: 'APPROVE_DOCTOR_VERIFICATION',
        adminUserId: adminId,
        targetUserId: userId,
        targetRole: targetRole,
        details: {
          'verification_request_id': verificationRequestId,
          'admin_notes': adminNotes,
        },
      );
    } catch (e) {
      throw Exception('Failed to approve doctor verification: $e');
    }
  }

  /// Approve caregiver verification with audit logging
  Future<void> approveCaregiverVerification({
    required String verificationRequestId,
    required String userId,
    String? adminNotes,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }

      // Get user role for audit log
      final user = await _client.from('users').select('role').eq('id', userId).maybeSingle();
      final targetRole = user?['role'] as String?;

      // Update verification request
      await _client.from('user_verification_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': adminId,
        'admin_notes': adminNotes,
      }).eq('id', verificationRequestId);

      // Update user status
      await _client.from('users').update({
        'verification_status': 'VERIFIED',
        'account_status': 'ACTIVE',
        'verification_completed_at': DateTime.now().toIso8601String(),
        'verified_by': adminId,
      }).eq('id', userId);

      // Update caregiver verification as verified
      await _client.from('caregiver_verification').update({
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Log audit entry
      await _logAuditEntry(
        action: 'APPROVE_CAREGIVER_VERIFICATION',
        adminUserId: adminId,
        targetUserId: userId,
        targetRole: targetRole,
        details: {
          'verification_request_id': verificationRequestId,
          'admin_notes': adminNotes,
        },
      );
    } catch (e) {
      throw Exception('Failed to approve caregiver verification: $e');
    }
  }

  /// Reject verification request with audit logging
  Future<void> rejectVerification({
    required String verificationRequestId,
    required String userId,
    required String rejectionReason,
    String? adminNotes,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }

      // Get user role for audit log
      final user = await _client.from('users').select('role').eq('id', userId).maybeSingle();
      final targetRole = user?['role'] as String?;

      // Update verification request
      await _client.from('user_verification_requests').update({
        'status': 'rejected',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': adminId,
        'rejection_reason': rejectionReason,
        'admin_notes': adminNotes,
      }).eq('id', verificationRequestId);

      // Update user status
      await _client.from('users').update({
        'verification_status': 'REJECTED',
        'account_status': 'SUSPENDED',
        'verification_completed_at': DateTime.now().toIso8601String(),
        'verification_rejected_reason': rejectionReason,
        'verified_by': adminId,
      }).eq('id', userId);

      // Log audit entry
      await _logAuditEntry(
        action: 'REJECT_VERIFICATION',
        adminUserId: adminId,
        targetUserId: userId,
        targetRole: targetRole,
        details: {
          'verification_request_id': verificationRequestId,
          'rejection_reason': rejectionReason,
          'admin_notes': adminNotes,
        },
      );
    } catch (e) {
      throw Exception('Failed to reject verification: $e');
    }
  }

  /// Get audit logs for admin dashboard
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final results = await _client
          .from('audit_logs')
          .select('*, admin_users:admin_user_id(name, email), target_users:target_user_id(name, email)')
          .order('timestamp', ascending: false)
          .range(offset, offset + limit - 1);

      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch audit logs: $e');
    }
  }
}
