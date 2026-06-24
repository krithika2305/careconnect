import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/providers.dart';
import '../../services/notification_service.dart';

class ConsultationService {
  static Future<void> joinConsultation(SupabaseClient client, String consultationId, String role) async {
    try {
      if (role == 'patient') {
        // Update status to active
        await client
            .from('consultations')
            .update({'status': 'active'})
            .eq('id', consultationId);

        // Fetch consultation details to notify doctor
        final consult = await client
            .from('consultations')
            .select('doctor_id')
            .eq('id', consultationId)
            .maybeSingle();

        final doctorId = consult?['doctor_id'] as String?;
        if (doctorId != null) {
          await NotificationService.send(
            userId: doctorId,
            title: 'Patient joined consultation',
            body: 'Patient joined consultation',
            type: 'consultation_joined',
          );
        }
      }
    } catch (e) {
      print('Error in joinConsultation: $e');
    }
  }

  static Future<void> endConsultation(SupabaseClient client, String consultationId) async {
    try {
      // 1. Fetch consultation details
      final consult = await client
          .from('consultations')
          .select('doctor_id, patient_id, caregiver_id, status')
          .eq('id', consultationId)
          .maybeSingle();

      if (consult == null || consult['status'] == 'completed' || consult['status'] == 'cancelled') {
        return;
      }

      final doctorId = consult['doctor_id'] as String?;
      final patientId = consult['patient_id'] as String?;
      final caregiverId = consult['caregiver_id'] as String?;

      // 2. Update status to completed
      await client
          .from('consultations')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', consultationId);

      // 3. Send notifications to all participants
      if (doctorId != null) {
        await NotificationService.send(
          userId: doctorId,
          title: 'Consultation completed',
          body: 'Consultation completed',
          type: 'consultation_ended',
        );
      }
      if (patientId != null) {
        await NotificationService.send(
          userId: patientId,
          title: 'Consultation completed',
          body: 'Consultation completed',
          type: 'consultation_ended',
        );
      }
      if (caregiverId != null && caregiverId.isNotEmpty) {
        await NotificationService.send(
          userId: caregiverId,
          title: 'Consultation completed',
          body: 'Consultation completed',
          type: 'consultation_ended',
        );
      }
    } catch (e) {
      print('Error in endConsultation: $e');
    }
  }
}

// StreamProvider that returns active/pending consultation for current user in real-time
final activeConsultationProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(authSessionProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;

  if (session == null || profile == null) {
    return Stream.value(null);
  }

  final userId = session.user.id;
  final role = profile['role']?.toString() ?? '';

  String filterField;
  if (role == 'patient') {
    filterField = 'patient_id';
  } else if (role == 'caregiver') {
    filterField = 'caregiver_id';
  } else if (role == 'doctor') {
    filterField = 'doctor_id';
  } else {
    return Stream.value(null);
  }

  return client
      .from('consultations')
      .stream(primaryKey: ['id'])
      .eq(filterField, userId)
      .map((list) {
        final activeList = list
            .where((row) => row['status'] == 'pending' || row['status'] == 'active')
            .toList();
        if (activeList.isEmpty) return null;

        // Sort by started_at descending to get the newest session
        activeList.sort((a, b) {
          final ta = DateTime.tryParse(a['started_at']?.toString() ?? '') ?? DateTime(1970);
          final tb = DateTime.tryParse(b['started_at']?.toString() ?? '') ?? DateTime(1970);
          return tb.compareTo(ta);
        });

        return Map<String, dynamic>.from(activeList.first);
      });
});
