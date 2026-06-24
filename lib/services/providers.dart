import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding_service.dart';
import 'user_profile_service.dart';

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
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    return await UserProfileService(client)
        .fetch(session.user.id)
        .timeout(const Duration(seconds: 6));
  } catch (_) {
    return null;
  }
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  return OnboardingService.isComplete();
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
// Doctor clinical — patients, prescriptions, per-patient MRI
// ─────────────────────────────────────────────────────────────

final doctorPatientsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final doctorId = supabase.auth.currentUser?.id;
  print('Doctor ID: $doctorId');
  if (doctorId == null) return [];
  
  final mappings = await supabase
      .from('doctor_patient_mapping')
      .select('patient_id')
      .eq('doctor_id', doctorId)
      .eq('status', 'accepted');
  print('Mappings: $mappings');
  
  if (mappings.isEmpty) return [];
  
  final patientIds = mappings.map((m) => m['patient_id'] as String).toList();
  print('Patient IDs: $patientIds');
  
  final patients = await supabase.from('users').select('id, name, email').inFilter('id', patientIds);
  print('Patients found: ${patients.length}');
  
  return patients;
});

final patientPrescriptionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final rows = await client
        .from('prescriptions')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final endStr = map['end_date']?.toString();
      final end = endStr != null ? DateTime.tryParse(endStr) : null;
      final active = end == null ||
          DateTime(end.year, end.month, end.day).isAfter(today) ||
          DateTime(end.year, end.month, end.day).isAtSameMomentAs(today);
      map['is_active'] = active;
      return map;
    }).toList();
  } catch (_) {
    return [];
  }
});

final patientMriHistoryProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('mri_predictions')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(20);
  } catch (_) {
    return [];
  }
});

final patientEmergencyHistoryProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('emergency_alerts')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(10);
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

/// Pending email invites sent by the current caregiver.
final myPendingInvitesProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('care_invites')
        .select()
        .eq('caregiver_id', session.user.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  } catch (_) {
    return [];
  }
});

/// All patients mapped to the current caregiver.
final myPatientsProvider = FutureProvider<List<dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  print('CAREGIVER ID: ${session.user.id}');
  try {
    final mappings = await client
        .from('caregiver_patient_mapping')
        .select('patient_id, created_at')
        .eq('caregiver_id', session.user.id)
        .order('created_at', ascending: false);
    print('MAPPINGS: $mappings');
    if (mappings.isEmpty) return [];

    final enriched = <Map<String, dynamic>>[];
    for (final row in mappings) {
      final patientId = row['patient_id'] as String;
      Map<String, dynamic>? userMeta;
      try {
        userMeta = await client
            .from('users')
            .select('id, name, email')
            .eq('id', patientId)
            .maybeSingle();
      } catch (_) {
        userMeta = null;
      }
      enriched.add({
        ...Map<String, dynamic>.from(row as Map),
        'users': userMeta,
      });
    }
    // Final sort – newest first
    enriched.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return bDate?.compareTo(aDate ?? DateTime(1970)) ?? 0;
    });
    print('ENRICHED PATIENTS: $enriched');
    return enriched;
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

// ─────────────────────────────────────────────────────────────
// Memory Photos
// ─────────────────────────────────────────────────────────────

final memoryPhotosProvider = FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('memory_photos')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Scheduled Messages (Reminders)
// ─────────────────────────────────────────────────────────────

final scheduledMessagesProvider = FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('scheduled_messages')
        .select()
        .eq('patient_id', patientId)
        .order('scheduled_time', ascending: true);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Geofences
// ─────────────────────────────────────────────────────────────

final geofenceProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('geofences')
        .select()
        .eq('patient_id', patientId)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

/// Active reminders for today with done/pending status from message_logs.
final todayRemindersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final reminders = await client
        .from('scheduled_messages')
        .select()
        .eq('patient_id', patientId)
        .eq('is_active', true)
        .order('scheduled_time', ascending: true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final logs = await client
        .from('message_logs')
        .select('message_id, status, delivered_at')
        .eq('patient_id', patientId)
        .gte('delivered_at', startOfDay.toIso8601String());

    final doneToday = <String>{};
    for (final log in logs) {
      final mid = log['message_id']?.toString();
      if (mid != null) doneToday.add(mid);
    }

    return reminders.map((r) {
      final id = r['id'].toString();
      return {
        ...Map<String, dynamic>.from(r as Map),
        'done_today': doneToday.contains(id),
      };
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Questionnaire responses for decline / trend charts.
final patientQuestionnaireResponsesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('questionnaire_responses')
        .select()
        .eq('patient_id', patientId)
        .order('submitted_at', ascending: true);
  } catch (_) {
    return [];
  }
});

/// Medication adherence percentage for the last 7 days by day of week.
final medicationAdherenceProvider = FutureProvider.family<Map<String, double>, String>((ref, patientId) async {
  final supabase = ref.read(supabaseClientProvider);
  final lastWeek = DateTime.now().subtract(const Duration(days: 7));
  // fetch all medication reminders for this patient in last 7 days
  final reminders = await supabase
      .from('scheduled_messages')
      .select('id, scheduled_time')
      .eq('patient_id', patientId)
      .eq('type', 'medication')
      .gte('scheduled_time', lastWeek.toIso8601String());
  // fetch logs for those reminders
  final logs = await supabase
      .from('message_logs')
      .select('message_id')
      .inFilter('message_id', reminders.map((r) => r['id']).toList());
  final takenIds = logs.map((l) => l['message_id'].toString()).toSet();
  // group by day
  final Map<String, List> dayMap = {};
  for (var r in reminders) {
    final day = DateTime.parse(r['scheduled_time']).toLocal().weekday;
    final dayName = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][day-1];
    dayMap.putIfAbsent(dayName, () => []).add(r['id']);
  }
  final result = <String, double>{};
  for (var entry in dayMap.entries) {
    final total = entry.value.length;
    final taken = entry.value.where((id) => takenIds.contains(id)).length;
    result[entry.key] = total == 0 ? 0 : (taken / total) * 100;
  }
  return result;
});

/// Fetches merged care activity for caregiver dashboards.
Future<List<Map<String, dynamic>>> fetchCaregiverActivity(
  SupabaseClient client,
  String patientId, {
  int perSourceLimit = 15,
  int maxItems = 5,
}) async {
  final items = <Map<String, dynamic>>[];

  final logs = await client
      .from('message_logs')
      .select('message_id, status, delivered_at')
      .eq('patient_id', patientId)
      .order('delivered_at', ascending: false)
      .limit(perSourceLimit);
  for (final log in logs) {
    items.add({
      'type': 'medication',
      'title': 'Reminder marked done',
      'time': log['delivered_at'],
    });
  }

  final responses = await client
      .from('questionnaire_responses')
      .select('period_label, submitted_at')
      .eq('patient_id', patientId)
      .order('submitted_at', ascending: false)
      .limit(perSourceLimit);
  for (final r in responses) {
    items.add({
      'type': 'questionnaire',
      'title': 'Questionnaire completed (${r['period_label']})',
      'time': r['submitted_at'],
    });
  }

  final alerts = await client
      .from('emergency_alerts')
      .select('alert_type, resolved_at, created_at, status')
      .eq('patient_id', patientId)
      .order('created_at', ascending: false)
      .limit(perSourceLimit);
  for (final a in alerts) {
    if (a['status'] == 'RESOLVED') {
      items.add({
        'type': 'alert',
        'title': '${a['alert_type']} resolved',
        'time': a['resolved_at'] ?? a['created_at'],
      });
    }
  }

  final tests = await client
      .from('cognitive_tests')
      .select('ai_status, created_at')
      .eq('patient_id', patientId)
      .order('created_at', ascending: false)
      .limit(perSourceLimit);
  for (final t in tests) {
    items.add({
      'type': 'cognitive',
      'title': 'Brain exercise: ${t['ai_status']}',
      'time': t['created_at'],
    });
  }

  try {
    final routineLogs = await client
        .from('routine_logs')
        .select('completed_at, daily_routines(task_name)')
        .eq('patient_id', patientId)
        .order('completed_at', ascending: false)
        .limit(perSourceLimit);
    for (final log in routineLogs) {
      final task = log['daily_routines']?['task_name'] ?? 'Routine task';
      items.add({
        'type': 'routine',
        'title': 'Daily routine done: $task',
        'time': log['completed_at'],
      });
    }
  } catch (_) {
    // routine tables may not exist yet
  }

  try {
    final moodLogs = await client
        .from('mood_logs')
        .select('mood, energy_level, logged_at')
        .eq('patient_id', patientId)
        .order('logged_at', ascending: false)
        .limit(perSourceLimit);
    for (final log in moodLogs) {
      final mood = log['mood']?.toString() ?? 'neutral';
      final energy = log['energy_level'];
      items.add({
        'type': 'mood',
        'title': 'Mood check-in: $mood (energy $energy/5)',
        'time': log['logged_at'],
      });
    }
  } catch (_) {
    // mood_logs table may not exist yet
  }

  try {
    final appts = await client
        .from('appointments')
        .select('doctor_name, appointment_type, appointment_time, created_at')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(perSourceLimit);
    for (final a in appts) {
      final doctor = a['doctor_name'] ?? 'Doctor';
      final type = a['appointment_type']?.toString();
      items.add({
        'type': 'appointment',
        'title': 'Visit scheduled: $doctor${type != null ? ' ($type)' : ''}',
        'time': a['created_at'] ?? a['appointment_time'],
      });
    }
  } catch (_) {
    // appointments table may not exist yet
  }

  items.sort((a, b) {
    final ta = DateTime.tryParse(a['time']?.toString() ?? '') ?? DateTime(1970);
    final tb = DateTime.tryParse(b['time']?.toString() ?? '') ?? DateTime(1970);
    return tb.compareTo(ta);
  });
  return items.take(maxItems).toList();
}

/// Last 5 activities on caregiver home dashboard.
final caregiverRecentActivityProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, patientId) async {
  try {
    final client = ref.read(supabaseClientProvider);
    return await fetchCaregiverActivity(client, patientId, maxItems: 5);
  } catch (_) {
    return [];
  }
});

/// Full activity history for "View all" screen.
final caregiverFullActivityProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, patientId) async {
  try {
    final client = ref.read(supabaseClientProvider);
    return await fetchCaregiverActivity(
      client,
      patientId,
      perSourceLimit: 30,
      maxItems: 50,
    );
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Mood & energy logs
// ─────────────────────────────────────────────────────────────

/// Morning = before 3pm local; evening = 3pm onward (twice daily).
bool moodLogIsMorningSlot(DateTime loggedAt) => loggedAt.hour < 15;

/// Today's mood logs with morning/evening slot flags for the patient UI.
final todayMoodStatusProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final logs = await client
        .from('mood_logs')
        .select()
        .eq('patient_id', patientId)
        .gte('logged_at', startOfDay.toIso8601String())
        .order('logged_at', ascending: false);

    Map<String, dynamic>? morningLog;
    Map<String, dynamic>? eveningLog;
    for (final raw in logs) {
      final log = Map<String, dynamic>.from(raw as Map);
      final at = DateTime.tryParse(log['logged_at']?.toString() ?? '')?.toLocal();
      if (at == null) continue;
      if (moodLogIsMorningSlot(at) && morningLog == null) {
        morningLog = log;
      } else if (!moodLogIsMorningSlot(at) && eveningLog == null) {
        eveningLog = log;
      }
    }

    final hour = now.hour;
    final currentSlot = hour < 15 ? 'morning' : 'evening';
    return {
      'morning_log': morningLog,
      'evening_log': eveningLog,
      'morning_done': morningLog != null,
      'evening_done': eveningLog != null,
      'current_slot': currentSlot,
    };
  } catch (_) {
    return {
      'morning_log': null,
      'evening_log': null,
      'morning_done': false,
      'evening_done': false,
      'current_slot': DateTime.now().hour < 15 ? 'morning' : 'evening',
    };
  }
});

/// Last 14 days of mood logs for caregiver trends.
final moodLogsTrendProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final since = DateTime.now().subtract(const Duration(days: 14)).toUtc();
    final rows = await client
        .from('mood_logs')
        .select()
        .eq('patient_id', patientId)
        .gte('logged_at', since.toIso8601String())
        .order('logged_at', ascending: true);
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Appointments & visits
// ─────────────────────────────────────────────────────────────

/// Upcoming appointments for patient view (next 90 days).
final patientAppointmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await client
        .from('appointments')
        .select()
        .eq('patient_id', patientId)
        .gte('appointment_time', now)
        .order('appointment_time', ascending: true)
        .limit(20);
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  } catch (_) {
    return [];
  }
});

/// All appointments for caregiver management (upcoming + recent past).
final allAppointmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final rows = await client
        .from('appointments')
        .select()
        .eq('patient_id', patientId)
        .order('appointment_time', ascending: false)
        .limit(50);
    final list = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    list.sort((a, b) {
      final ta = DateTime.tryParse(a['appointment_time']?.toString() ?? '') ?? DateTime(1970);
      final tb = DateTime.tryParse(b['appointment_time']?.toString() ?? '') ?? DateTime(1970);
      final now = DateTime.now();
      final aUp = ta.isAfter(now);
      final bUp = tb.isAfter(now);
      if (aUp != bUp) return aUp ? -1 : 1;
      if (aUp) return ta.compareTo(tb);
      return tb.compareTo(ta);
    });
    return list;
  } catch (_) {
    return [];
  }
});

/// Next upcoming appointment (dashboard preview).
final nextAppointmentProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, patientId) async {
  final list = await ref.watch(patientAppointmentsProvider(patientId).future);
  return list.isEmpty ? null : list.first;
});

// ─────────────────────────────────────────────────────────────
// Daily routines (checklist)
// ─────────────────────────────────────────────────────────────

final dailyRoutinesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('daily_routines')
        .select()
        .eq('patient_id', patientId)
        .eq('is_active', true)
        .order('time_of_day')
        .order('display_order', ascending: true);
  } catch (_) {
    return [];
  }
});

/// All routines for caregiver management (includes inactive).
final caregiverDailyRoutinesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('daily_routines')
        .select()
        .eq('patient_id', patientId)
        .order('time_of_day')
        .order('display_order', ascending: true);
  } catch (_) {
    return [];
  }
});

/// Active routines with today's completion status for patient checklist.
final todayDailyRoutinesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final routines = await client
        .from('daily_routines')
        .select()
        .eq('patient_id', patientId)
        .eq('is_active', true)
        .order('time_of_day')
        .order('display_order', ascending: true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final logs = await client
        .from('routine_logs')
        .select('routine_id, completed_at')
        .eq('patient_id', patientId)
        .gte('completed_at', startOfDay.toIso8601String());

    final doneIds = <String>{};
    for (final log in logs) {
      final rid = log['routine_id']?.toString();
      if (rid != null) doneIds.add(rid);
    }

    return routines.map((r) {
      final id = r['id'].toString();
      return {
        ...Map<String, dynamic>.from(r as Map),
        'done_today': doneIds.contains(id),
      };
    }).toList();
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Chat Messages (Caregiver-Doctor Messaging)
// ─────────────────────────────────────────────────────────────

/// Chat messages between two users for a specific patient.
final chatMessagesProvider = FutureProvider.family<List<Map<String, dynamic>>, ChatConversationKey>(
  (ref, key) async {
    final client = ref.read(supabaseClientProvider);
    try {
      return await client
          .from('chat_messages')
          .select()
          .or('and(sender_id.eq.${key.userId},receiver_id.eq.${key.otherUserId}),and(sender_id.eq.${key.otherUserId},receiver_id.eq.${key.userId})')
          .eq('patient_id', key.patientId)
          .order('created_at', ascending: true);
    } catch (_) {
      return [];
    }
  },
);

/// Unread message count for a user.
final unreadMessageCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final result = await client
        .from('chat_messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', false);
    return result.length;
  } catch (_) {
    return 0;
  }
});

/// Key for chat conversation provider.
class ChatConversationKey {
  final String userId;
  final String otherUserId;
  final String patientId;

  ChatConversationKey({
    required this.userId,
    required this.otherUserId,
    required this.patientId,
  });

  @override
  bool operator ==(Object other) =>
      other is ChatConversationKey &&
      other.userId == userId &&
      other.otherUserId == otherUserId &&
      other.patientId == patientId;

  @override
  int get hashCode => Object.hash(userId, otherUserId, patientId);
}

// ─────────────────────────────────────────────────────────────
// Doctor-Patient Assignment
// ─────────────────────────────────────────────────────────────

/// Assigned patients for a doctor (accepted assignments only)
final assignedPatientsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, doctorId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('doctor_patient_mapping')
        .select('patient_id, assigned_at')
        .eq('doctor_id', doctorId)
        .eq('status', 'accepted')
        .order('assigned_at', ascending: false);
  } catch (_) {
    return [];
  }
});

/// Assigned doctors for a patient
final assignedDoctorsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final mappings = await client
        .from('doctor_patient_mapping')
        .select('doctor_id, status, assigned_at')
        .eq('patient_id', patientId)
        .order('assigned_at', ascending: false);

    final doctorIds = mappings.map((m) => m['doctor_id'] as String).toList();
    if (doctorIds.isEmpty) return [];

    final doctors = await client
        .from('users')
        .select('id, name, email')
        .inFilter('id', doctorIds);

    return mappings.map((m) {
      final doctor = doctors.firstWhere((d) => d['id'] == m['doctor_id'], orElse: () => {});
      return {
        ...Map<String, dynamic>.from(m as Map),
        'doctor_name': doctor['name']?.toString() ?? 'Doctor',
        'doctor_email': doctor['email']?.toString() ?? '',
      };
    }).toList();
  } catch (_) {
    return [];
  }
});

/// All available doctors for caregiver to assign
final availableDoctorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('users')
        .select('id, name, email')
        .eq('role', 'doctor')
        .order('name');
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Admin Providers (System Logs & Users)
// ─────────────────────────────────────────────────────────────

final allUsersAdminProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('users')
        .select()
        .order('created_at', ascending: false);
  } catch (_) {
    return [];
  }
});

final adminSystemLogsProvider = FutureProvider<Map<String, List<dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final alertsReq = client.from('emergency_alerts').select().order('created_at', ascending: false).limit(50);
    final messagesReq = client.from('message_logs').select().order('delivered_at', ascending: false).limit(50);
    final mriReq = client.from('mri_predictions').select().order('created_at', ascending: false).limit(50);

    final List<dynamic> results = await Future.wait([alertsReq, messagesReq, mriReq]);

    return {
      'emergency_alerts': results[0] as List<dynamic>,
      'message_logs': results[1] as List<dynamic>,
      'mri_predictions': results[2] as List<dynamic>,
    };
  } catch (e) {
    return {'emergency_alerts': [], 'message_logs': [], 'mri_predictions': []};
  }
});
// Helper function to filter notifications based on user relationships and print logs
Future<List<Map<String, dynamic>>> _filterNotificationsList(
  SupabaseClient supabase,
  String currentUserId,
  String role,
  List<Map<String, dynamic>> notifications,
) async {
  final filtered = <Map<String, dynamic>>[];

  // Fetch caregiver mapping patient IDs
  final Set<String> linkedPatientIds = {};
  if (role == 'caregiver') {
    try {
      final mappings = await supabase
          .from('caregiver_patient_mapping')
          .select('patient_id')
          .eq('caregiver_id', currentUserId);
      for (final m in mappings) {
        final pid = m['patient_id'] as String?;
        if (pid != null) linkedPatientIds.add(pid);
      }
    } catch (_) {}
  }

  // Fetch doctor mapping patient IDs
  final Set<String> assignedPatientIds = {};
  if (role == 'doctor') {
    try {
      final mappings = await supabase
          .from('doctor_patient_mapping')
          .select('patient_id')
          .eq('doctor_id', currentUserId)
          .eq('status', 'accepted');
      for (final m in mappings) {
        final pid = m['patient_id'] as String?;
        if (pid != null) assignedPatientIds.add(pid);
      }
    } catch (_) {}
  }

  for (final n in notifications) {
    // Extract patient_id from data JSON column if present
    String? patientId;
    final rawData = n['data'];
    if (rawData != null) {
      Map<String, dynamic>? dataMap;
      if (rawData is Map) {
        dataMap = Map<String, dynamic>.from(rawData);
      } else if (rawData is String) {
        try {
          dataMap = jsonDecode(rawData) as Map<String, dynamic>;
        } catch (_) {}
      }
      patientId = dataMap?['patient_id']?.toString();
    }

    if (patientId == null && role == 'patient') {
      patientId = currentUserId;
    }

    List<String> recipientIds = [];
    bool isVisible = false;

    if (role == 'admin') {
      recipientIds = [currentUserId];
      isVisible = n['user_id'] == currentUserId;
    } else if (role == 'patient') {
      recipientIds = [currentUserId];
      // Patients only receive their own notifications
      isVisible = n['user_id'] == currentUserId;
    } else if (role == 'doctor') {
      if (patientId != null) {
        recipientIds = [currentUserId];
        isVisible = assignedPatientIds.contains(patientId);
      } else {
        recipientIds = [currentUserId];
        isVisible = n['user_id'] == currentUserId;
      }
    } else if (role == 'caregiver') {
      if (patientId != null) {
        recipientIds = [currentUserId];
        isVisible = linkedPatientIds.contains(patientId);
      } else {
        recipientIds = [currentUserId];
        isVisible = n['user_id'] == currentUserId;
      }
    }

    // Required debug logs
    print('NOTIFICATION USER: $currentUserId');
    print('NOTIFICATION ROLE: $role');
    print('NOTIFICATION PATIENT: $patientId');
    print('NOTIFICATION RECIPIENTS: $recipientIds');
    print('NOTIFICATION FILTER RESULT: ${isVisible ? "allowed" : "blocked"} (title: ${n['title']})');

    if (isVisible) {
      filtered.add(n);
    }
  }

  return filtered;
}

// Fetch notifications as a Future (not stream) – simpler and avoids stream eq issues
final userNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {

  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  print('========== PROVIDER DEBUG ==========');
  print('CURRENT USER ID: $userId');

  if (userId == null) {
    print('USER ID IS NULL');
    return [];
  }

  final profile = await ref.watch(userProfileProvider.future);
  final role = profile?['role']?.toString().toLowerCase() ?? 'patient';

  final data = await supabase
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  final list = List<Map<String, dynamic>>.from(data);
  final filtered = await _filterNotificationsList(supabase, userId, role, list);

  print('NOTIFICATION COUNT: ${filtered.length}');
  print('NOTIFICATION DATA: $filtered');

  return filtered;
});

// Unread count – simple Future query
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;

  final profile = await ref.watch(userProfileProvider.future);
  final role = profile?['role']?.toString().toLowerCase() ?? 'patient';

  final data = await supabase
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .eq('is_read', false)
      .order('created_at', ascending: false);

  final list = List<Map<String, dynamic>>.from(data);
  final filtered = await _filterNotificationsList(supabase, userId, role, list);
  return filtered.length;
});

// ─────────────────────────────────────────────────────────────
// Verification Providers
// ─────────────────────────────────────────────────────────────

/// Current user's verification status
final myVerificationStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('users')
        .select(
            'verification_status, account_status, verification_requested_at, verification_completed_at, verification_rejected_reason')
        .eq('id', session.user.id)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

/// Doctor credentials for current user
final myDoctorCredentialsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('doctor_credentials')
        .select()
        .eq('user_id', session.user.id)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

/// Caregiver verification for current user
final myCaregiverVerificationProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    return await client
        .from('caregiver_verification')
        .select()
        .eq('user_id', session.user.id)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

/// Get verification request for current user
final myVerificationRequestProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    final requests = await client
        .from('user_verification_requests')
        .select()
        .eq('user_id', session.user.id)
        .order('submitted_at', ascending: false)
        .limit(1);

    if (requests.isEmpty) return null;
    return requests.first as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

/// Admin: All pending verification requests
final pendingVerificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final results = await client
        .from('user_verification_requests')
        .select('*, users:user_id(id, name, email, role, created_at)')
        .eq('status', 'pending')
        .order('submitted_at', ascending: true);

    return results.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

/// Admin: Verification metrics
final verificationMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final pending = await client
        .from('user_verification_requests')
        .select()
        .eq('status', 'pending');
    final approved = await client
        .from('user_verification_requests')
        .select()
        .eq('status', 'approved');
    final rejected = await client
        .from('user_verification_requests')
        .select()
        .eq('status', 'rejected');

    final pendingDoctors = (pending as List).where((r) => r['role'] == 'doctor').length;
    final pendingCaregivers = (pending as List).where((r) => r['role'] == 'caregiver').length;

    return {
      'total_pending': pending.length,
      'total_approved': approved.length,
      'total_rejected': rejected.length,
      'pending_doctors': pendingDoctors,
      'pending_caregivers': pendingCaregivers,
    };
  } catch (_) {
    return {
      'total_pending': 0,
      'total_approved': 0,
      'total_rejected': 0,
      'pending_doctors': 0,
      'pending_caregivers': 0,
    };
  }
});

/// Admin: All pending users (account status PENDING)
final pendingUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final results = await client
        .from('users')
        .select()
        .eq('account_status', 'PENDING')
        .order('created_at', ascending: true);

    return results.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

/// Admin: Fetch specific user verification details
final userVerificationDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final user = await client.from('users').select().eq('id', userId).maybeSingle();

    if (user == null) return null;

    Map<String, dynamic>? credentials;
    Map<String, dynamic>? caregiver;
    Map<String, dynamic>? request;

    if (user['role'] == 'doctor') {
      credentials = await client
          .from('doctor_credentials')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    }

    if (user['role'] == 'caregiver') {
      caregiver = await client
          .from('caregiver_verification')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    }

    final requests = await client
        .from('user_verification_requests')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false)
        .limit(1);

    if (requests.isNotEmpty) {
      request = requests.first as Map<String, dynamic>;
    }

    return {
      'user': user,
      'credentials': credentials,
      'caregiver_verification': caregiver,
      'verification_request': request,
    };
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────
// Admin Dashboard Stats Providers
// ─────────────────────────────────────────────────────────────

/// Admin: Dashboard overview statistics
final adminDashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    // Get total users by role
    final allUsers = await client.from('users').select('role, account_status, verification_status');
    
    int totalUsers = allUsers.length;
    int totalDoctors = 0;
    int totalCaregivers = 0;
    int totalPatients = 0;
    int suspendedAccounts = 0;
    int activeAccounts = 0;
    int verifiedDoctors = 0;
    int verifiedCaregivers = 0;
    
    for (final user in allUsers) {
      final role = user['role'] as String?;
      final accountStatus = user['account_status'] as String?;
      final verificationStatus = user['verification_status'] as String?;
      
      if (role == 'doctor') {
        totalDoctors++;
        if (verificationStatus == 'VERIFIED') verifiedDoctors++;
      } else if (role == 'caregiver') {
        totalCaregivers++;
        if (verificationStatus == 'VERIFIED') verifiedCaregivers++;
      } else if (role == 'patient') {
        totalPatients++;
      }
      
      if (accountStatus == 'SUSPENDED') suspendedAccounts++;
      if (accountStatus == 'ACTIVE') activeAccounts++;
    }
    
    // Get pending verifications
    final pendingVerifications = await client
        .from('user_verification_requests')
        .select()
        .eq('status', 'pending');
    
    // Get emergency alerts
    int emergencyAlerts = 0;
    try {
      final alerts = await client
          .from('emergency_alerts')
          .select()
          .eq('resolved', false);
      emergencyAlerts = alerts.length;
    } catch (_) {
      emergencyAlerts = 0;
    }
    
    return {
      'total_users': totalUsers,
      'total_doctors': totalDoctors,
      'total_caregivers': totalCaregivers,
      'total_patients': totalPatients,
      'pending_verifications': pendingVerifications.length,
      'verified_doctors': verifiedDoctors,
      'verified_caregivers': verifiedCaregivers,
      'suspended_accounts': suspendedAccounts,
      'active_accounts': activeAccounts,
      'emergency_alerts': emergencyAlerts,
    };
  } catch (e) {
    return {
      'total_users': 0,
      'total_doctors': 0,
      'total_caregivers': 0,
      'total_patients': 0,
      'pending_verifications': 0,
      'verified_doctors': 0,
      'verified_caregivers': 0,
      'suspended_accounts': 0,
      'active_accounts': 0,
      'emergency_alerts': 0,
    };
  }
});

/// Admin: Audit logs for dashboard
final adminAuditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final results = await client
        .from('audit_logs')
        .select('*, admin_users:admin_user_id(name, email), target_users:target_user_id(name, email)')
        .order('timestamp', ascending: false)
        .limit(50);

    return results.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class AppSettings {
  final String language;
  final bool darkMode;
  final String fontSize; // 'small', 'medium', 'large', 'extra_large'
  final bool emailNotifications;
  final bool pushNotifications;
  final bool emergencyAlerts;

  AppSettings({
    this.language = 'en',
    this.darkMode = false,
    this.fontSize = 'medium',
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.emergencyAlerts = true,
  });

  AppSettings copyWith({
    String? language,
    bool? darkMode,
    String? fontSize,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? emergencyAlerts,
  }) {
    return AppSettings(
      language: language ?? this.language,
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emergencyAlerts: emergencyAlerts ?? this.emergencyAlerts,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppSettings(
        language: prefs.getString('language') ?? 'en',
        darkMode: prefs.getBool('darkMode') ?? false,
        fontSize: prefs.getString('fontSize') ?? 'medium',
        emailNotifications: prefs.getBool('email_notifications') ?? true,
        pushNotifications: prefs.getBool('push_notifications') ?? true,
        emergencyAlerts: prefs.getBool('emergency_alerts') ?? true,
      );
      print('SETTING LOADED: language=${state.language}, darkMode=${state.darkMode}, fontSize=${state.fontSize}');
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> setLanguage(String value) async {
    state = state.copyWith(language: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    print('SETTING SAVED: language=$value');
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    print('SETTING SAVED: darkMode=$value');
  }

  Future<void> setFontSize(String value) async {
    state = state.copyWith(fontSize: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', value);
    print('SETTING SAVED: fontSize=$value');
  }

  Future<void> setEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications', value);
    print('SETTING SAVED: email_notifications=$value');
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', value);
    print('SETTING SAVED: push_notifications=$value');
  }

  Future<void> setEmergencyAlerts(bool value) async {
    state = state.copyWith(emergencyAlerts: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('emergency_alerts', value);
    print('SETTING SAVED: emergency_alerts=$value');
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});