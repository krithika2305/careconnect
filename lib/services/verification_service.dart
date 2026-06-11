import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for user verification submissions and queries
class VerificationService {
  VerificationService(this._client);

  final SupabaseClient _client;

  /// Fetch current user's verification status
  Future<Map<String, dynamic>?> fetchVerificationStatus(String userId) async {
    try {
      final user = await _client
          .from('users')
          .select(
              'id, verification_status, account_status, verification_requested_at, verification_rejected_reason')
          .eq('id', userId)
          .maybeSingle();
      return user;
    } catch (e) {
      throw Exception('Failed to fetch verification status: $e');
    }
  }

  Future<String> uploadVerificationDocument({
    required String bucket,
    required String storagePath,
    required List<int> bytes,
  }) async {
    try {
      await _client.storage.from(bucket).uploadBinary(storagePath, bytes);
      return _client.storage.from(bucket).getPublicUrl(storagePath);
    } catch (e) {
      throw Exception('Failed to upload verification document: $e');
    }
  }

  /// Submit doctor credentials for verification
  Future<void> submitDoctorCredentials({
    required String userId,
    required String licenseNumber,
    required String licenseState,
    required String medicalSchool,
    required int yearsExperience,
    required String specialization,
    required bool boardCertified,
    String? licenseDocumentUrl,
  }) async {
    try {
      // Create or update doctor credentials
      await _client.from('doctor_credentials').upsert(
        {
          'user_id': userId,
          'license_number': licenseNumber,
          'license_state': licenseState,
          'medical_school': medicalSchool,
          'years_experience': yearsExperience,
          'specialization': specialization,
          'board_certified': boardCertified,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      final submittedDocuments = {
        'license_number': licenseNumber,
        'specialization': specialization,
      };
      if (licenseDocumentUrl != null) {
        submittedDocuments['license_document_url'] = licenseDocumentUrl;
      }

      // Create verification request
      await _client.from('user_verification_requests').insert({
        'user_id': userId,
        'role': 'doctor',
        'verification_type': 'credentials',
        'status': 'pending',
        'submitted_documents': submittedDocuments,
      });

      // Update user status
      await _client.from('users').update({
        'verification_status': 'PENDING_REVIEW',
        'verification_requested_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to submit doctor credentials: $e');
    }
  }

  /// Submit caregiver verification information
  Future<void> submitCaregiverVerification({
    required String userId,
    required String professionalBackground,
    required bool trainingCertificate,
    required String backgroundCheckStatus,
    String? idDocumentUrl,
  }) async {
    try {
      // Create or update caregiver verification
      await _client.from('caregiver_verification').upsert(
        {
          'user_id': userId,
          'professional_background': professionalBackground,
          'training_certificate': trainingCertificate,
          'background_check_status': backgroundCheckStatus,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      final submittedDocuments = {
        'professional_background': professionalBackground,
        'training_certificate': trainingCertificate,
      };
      if (idDocumentUrl != null) {
        submittedDocuments['id_document_url'] = idDocumentUrl;
      }

      // Create verification request
      await _client.from('user_verification_requests').insert({
        'user_id': userId,
        'role': 'caregiver',
        'verification_type': 'background_and_training',
        'status': 'pending',
        'submitted_documents': submittedDocuments,
      });

      // Update user status
      await _client.from('users').update({
        'verification_status': 'PENDING_REVIEW',
        'verification_requested_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to submit caregiver verification: $e');
    }
  }

  /// Fetch doctor credentials
  Future<Map<String, dynamic>?> fetchDoctorCredentials(String userId) async {
    try {
      return await _client
          .from('doctor_credentials')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      throw Exception('Failed to fetch doctor credentials: $e');
    }
  }

  /// Fetch caregiver verification
  Future<Map<String, dynamic>?> fetchCaregiverVerification(
      String userId) async {
    try {
      return await _client
          .from('caregiver_verification')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      throw Exception('Failed to fetch caregiver verification: $e');
    }
  }

  /// Get verification request details
  Future<Map<String, dynamic>?> fetchVerificationRequest(String userId) async {
    try {
      final requests = await _client
          .from('user_verification_requests')
          .select()
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(1);

      if (requests.isEmpty) return null;
      return requests.first as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch verification request: $e');
    }
  }
}
