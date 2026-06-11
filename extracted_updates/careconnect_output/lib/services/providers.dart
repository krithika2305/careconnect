import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
// Core Supabase providers
// ─────────────────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final authSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session ?? Supabase.instance.client.auth.currentSession;
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('users')
        .select()
        .eq('id', session.user.id)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────
// Cognitive test history
// ─────────────────────────────────────────────────────────────

final cognitiveHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('cognitive_tests')
        .select()
        .eq('user_id', session.user.id)
        .order('created_at', ascending: true);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// MRI prediction history
// ─────────────────────────────────────────────────────────────

final mriHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('mri_predictions')
        .select()
        .eq('doctor_id', session.user.id)
        .order('created_at', ascending: false);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Emergency alerts – REAL-TIME stream (replaces one-off fetch)
// Caregivers only see alerts for their mapped patients (enforced by RLS).
// ─────────────────────────────────────────────────────────────

final activeEmergencyAlertsProvider = StreamProvider<List<dynamic>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('emergency_alerts')
      .stream(primaryKey: ['id'])
      .eq('status', 'ACTIVE')
      .order('created_at', ascending: false);
});

final emergencyHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('emergency_alerts')
        .select()
        .order('created_at', ascending: false);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Patient profile (for caregiver to manage)
// ─────────────────────────────────────────────────────────────

/// The profile of the patient the current caregiver is assigned to.
/// Returns null if not yet created.
final patientProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('patient_profiles')
        .select()
        .eq('patient_id', patientId)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

/// All patients mapped to the current caregiver.
final myPatientsProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('caregiver_patient_mapping')
        .select('patient_id, users!patient_id(id, name, email)')
        .eq('caregiver_id', session.user.id);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Questionnaire questions (admin-managed)
// ─────────────────────────────────────────────────────────────

final questionnaireQuestionsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('questionnaire_questions')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
  } catch (_) {
    return [];
  }
});

/// All questions – including inactive (for admin management screen).
final allQuestionsAdminProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('questionnaire_questions')
        .select()
        .order('sort_order', ascending: true);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Questionnaire responses
// ─────────────────────────────────────────────────────────────

/// Responses submitted by the current caregiver.
final myResponsesProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('questionnaire_responses')
        .select()
        .eq('caregiver_id', session.user.id)
        .order('submitted_at', ascending: false);
  } catch (_) {
    return [];
  }
});

/// All responses – visible to admin.
final allResponsesAdminProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('questionnaire_responses')
        .select(
            '*, patient_profiles!patient_id(full_name), users!caregiver_id(name)')
        .order('submitted_at', ascending: false);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Patient stages
// ─────────────────────────────────────────────────────────────

final patientStagesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('patient_stages')
        .select()
        .eq('patient_id', patientId)
        .order('assigned_at', ascending: false);
  } catch (_) {
    return [];
  }
});

/// Latest stage for a patient (used in caregiver/doctor dashboards).
final latestPatientStageProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('patient_stages')
        .select()
        .eq('patient_id', patientId)
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});
