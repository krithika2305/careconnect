import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import 'alerts_screen.dart';
import 'caregiver_activity_log_screen.dart';
import 'caregiver_questionnaire_screen.dart';
import 'cognitive_trend_screen.dart';
import 'mood_trend_screen.dart';
import 'geofence_screen.dart';
import 'reminders_screen.dart';
import 'manage_daily_routines_screen.dart';
import 'manage_appointments_screen.dart';
import '../shared/appointment_card.dart';
import 'patient_profile_form_screen.dart';
import '../shared/memory_photos_screen.dart';
import '../shared/medication_reminder_card.dart';
import '../shared/chat_screen.dart';
import 'widgets/caregiver_ui.dart';
import '../../core/widgets/notification_bell.dart';
import '../video_call/consultation_service.dart';
import '../video_call/incoming_consultation_card.dart';

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _formatHeaderDate() {
  final now = DateTime.now();
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
}

int? _ageFromDob(String? dob) {
  if (dob == null || dob.isEmpty) return null;
  final parsed = DateTime.tryParse(dob);
  if (parsed == null) return null;
  final now = DateTime.now();
  var age = now.year - parsed.year;
  if (now.month < parsed.month ||
      (now.month == parsed.month && now.day < parsed.day)) {
    age--;
  }
  return age;
}

int _questionnaireScore(Map<String, dynamic> response) {
  final answers = response['answers'];
  if (answers is! Map) return 0;
  var score = 0;
  for (final v in answers.values) {
    if (v == 'Yes') {
      score += 2;
    } else if (v == 'Sometimes') {
      score += 1;
    }
  }
  return score;
}

double _declinePercent(List<dynamic> responses) {
  if (responses.length < 2) return 8.0;
  final sorted = [...responses]
    ..sort((a, b) {
      final ta = DateTime.tryParse(a['submitted_at']?.toString() ?? '') ?? DateTime(1970);
      final tb = DateTime.tryParse(b['submitted_at']?.toString() ?? '') ?? DateTime(1970);
      return ta.compareTo(tb);
    });
  final latest = _questionnaireScore(sorted.last);
  final cutoff = DateTime.now().subtract(const Duration(days: 180));
  final baseline = sorted.firstWhere(
    (r) {
      final t = DateTime.tryParse(r['submitted_at']?.toString() ?? '');
      return t != null && t.isBefore(cutoff.add(const Duration(days: 30)));
    },
    orElse: () => sorted.first,
  );
  final base = _questionnaireScore(baseline);
  if (base == 0) return (latest * 4.0).clamp(0, 100);
  return (((latest - base) / base) * 100).clamp(0, 100);
}

String _formatTime(String? time) {
  if (time == null) return '';
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final period = h >= 12 ? 'PM' : 'AM';
  final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$hour:$m $period';
}

// ─────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────

class CaregiverDashboard extends ConsumerStatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  ConsumerState<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends ConsumerState<CaregiverDashboard> {
  List<dynamic> records = [];
  bool loading = true;
  final Set<String> _resolvedAlertIds = {};
  String? _resolvingAlertId;
  final Set<String> _loggingReminderIds = {};
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    fetchPatientData();
  }

  Future<void> fetchPatientData() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final mappings = await ref.read(myPatientsProvider.future);
      final patientIds = mappings
          .map((m) => m['patient_id'] as String?)
          .whereType<String>()
          .toList();

      List<dynamic> data;
      if (patientIds.isEmpty) {
        data = [];
      } else if (patientIds.length == 1) {
        data = await client
            .from('cognitive_tests')
            .select()
            .eq('patient_id', patientIds.first)
            .order('created_at', ascending: false);
      } else {
        data = await client
            .from('cognitive_tests')
            .select()
            .inFilter('patient_id', patientIds)
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          records = data;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database error: $e'), backgroundColor: MedicalTheme.accentCoral),
        );
      }
    }
  }

  Future<void> logout() async {
    await ref.read(supabaseClientProvider).auth.signOut();
    ref.invalidate(authSessionProvider);
    ref.invalidate(userProfileProvider);
    if (mounted) context.go('/welcome');
  }

  Future<void> _refreshAll() async {
  ref.invalidate(myPatientsProvider);
  ref.invalidate(myPendingInvitesProvider);

  // ✅ use refresh() not read() — forces real Supabase fetch, ignores cache
  final myPatients = await ref.refresh(myPatientsProvider.future);

  // Pick newest patient — fall back to first if no created_at
  String? newestPatientId;
  DateTime? newestDate;
  for (var p in myPatients) {
    final createdAt = DateTime.tryParse(p['created_at']?.toString() ?? '');
    if (createdAt != null &&
        (newestDate == null || createdAt.isAfter(newestDate))) {
      newestDate = createdAt;
      newestPatientId = p['patient_id']?.toString();
    }
  }

  // ✅ If no created_at found (upsert didn't set it), just take last in list
  final patientId = newestPatientId ??
      (myPatients.isNotEmpty
          ? myPatients.last['patient_id']?.toString()
          : null);

  if (mounted) setState(() => _selectedPatientId = patientId);

  if (patientId != null) {
    ref.invalidate(latestPatientStageProvider(patientId));
    ref.invalidate(patientQuestionnaireResponsesProvider(patientId));
    ref.invalidate(patientProfileProvider(patientId));
    ref.invalidate(todayRemindersProvider(patientId));
    ref.invalidate(caregiverRecentActivityProvider(patientId));
    ref.invalidate(memoryPhotosProvider(patientId));
    ref.invalidate(geofenceProvider(patientId));
    ref.invalidate(caregiverDailyRoutinesProvider(patientId));
    ref.invalidate(todayDailyRoutinesProvider(patientId));
    ref.invalidate(caregiverFullActivityProvider(patientId));
    ref.invalidate(patientAppointmentsProvider(patientId));
    ref.invalidate(allAppointmentsProvider(patientId));
    ref.invalidate(nextAppointmentProvider(patientId));
  }

  await fetchPatientData();
}
  void _openWithPatient(String? patientId, VoidCallback action) {
    print('=== _openWithPatient called ===');
    print('Patient ID: $patientId');
    if (patientId != null) {
      print('Patient ID is not null, calling action');
      action();
      return;
    }
    print('Patient ID is null, showing link patient sheet');
    _showLinkPatientSheet();
  }

  Future<void> _showLinkPatientSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CareTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Link your loved one first',
              textAlign: TextAlign.center,
              style: CareTheme.displaySerif.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'Dashboard tools unlock after you connect a patient account by email.',
              textAlign: TextAlign.center,
              style: CareTheme.bodySans.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.push('/caregiver/invite');
                await _refreshAll();
              },
              child: const Text('Add loved one'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markReminderDone(String patientId, String reminderId) async {
    setState(() => _loggingReminderIds.add(reminderId));
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('message_logs').insert({
        'message_id': reminderId,
        'patient_id': patientId,
        'status': 'acknowledged',
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidate(todayRemindersProvider(patientId));
      ref.invalidate(caregiverRecentActivityProvider(patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged as done.'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log: $e'), backgroundColor: MedicalTheme.accentCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingReminderIds.remove(reminderId));
    }
  }

  Future<void> _showEmergencyContact(String? phone, String? name) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CareTheme.surface,
        title: Text('Emergency contact', style: CareTheme.displaySerif.copyWith(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null && name.isNotEmpty)
              Text(name, style: CareTheme.bodySans.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              phone?.isNotEmpty == true ? phone! : 'No phone number on file.',
              style: CareTheme.bodySans,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (phone != null && phone.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.phone_rounded),
              label: const Text('Call now'),
            ),
        ],
      ),
    );
  }

  Future<void> _showDoctorSelectionSheet(String patientId, String patientName) async {
    print('=== _showDoctorSelectionSheet called ===');
    print('Patient ID: $patientId, Patient Name: $patientName');
    final client = ref.read(supabaseClientProvider);
    try {
      print('Fetching assigned doctors...');
      final assignedDoctors = await _fetchAssignedDoctors(client, patientId);
      print('Assigned doctors: ${assignedDoctors.length}');

      print('Fetching available doctors...');
      final availableDoctors = await _fetchAvailableDoctors(client);
      print('Available doctors: ${availableDoctors.length}');

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: CareTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                Text(
                  'Manage Doctors',
                  textAlign: TextAlign.center,
                  style: CareTheme.displaySerif.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (assignedDoctors.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No doctors assigned yet',
                            textAlign: TextAlign.center,
                            style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                          ),
                        )
                      else ...[
                        Text(
                          'Assigned Doctors',
                          style: CareTheme.bodySans.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...assignedDoctors.map((assignment) {
                          final status = assignment['status']?.toString() ?? 'pending';
                          final doctorName = assignment['doctor_name']?.toString() ?? 'Doctor';
                          final doctorEmail = assignment['doctor_email']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: status == 'accepted'
                                    ? MedicalTheme.accentGreen.withValues(alpha: 0.1)
                                    : CareTheme.warning.withValues(alpha: 0.1),
                                child: Text(
                                  doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                                  style: TextStyle(
                                    color: status == 'accepted'
                                        ? MedicalTheme.accentGreen
                                        : CareTheme.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(doctorName),
                              subtitle: Text('$doctorEmail • ${status.toUpperCase()}'),
                              trailing: status == 'accepted'
                                  ? IconButton(
                                      icon: const Icon(Icons.chat_outlined),
                                      onPressed: () {
                                        print('====================');
                                        print('DOCTOR = $doctorName');
                                        print('DOCTOR ID = ${assignment['doctor_id']}');
                                        print('PATIENT ID = $patientId');
                                        print('PATIENT NAME = $patientName');
                                        print('====================');

                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              otherUserId: assignment['doctor_id'].toString(),
                                              otherUserName: doctorName,
                                              patientId: patientId,
                                              patientName: patientName,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : status == 'pending'
                                      ? Text(
                                          'Pending',
                                          style: CareTheme.bodySans.copyWith(
                                            fontSize: 11,
                                            color: CareTheme.warning,
                                          ),
                                        )
                                      : null,
                            ),
                          );
                        }).toList(),
                      ],
                      const SizedBox(height: 16),
                      if (availableDoctors.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.person_off_outlined, color: CareTheme.textMuted, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No doctors in system',
                                textAlign: TextAlign.center,
                                style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ask a doctor to create an account first',
                                textAlign: TextAlign.center,
                                style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildAvailableDoctorsSection(
                          ctx,
                          client,
                          patientId,
                          assignedDoctors,
                          availableDoctors,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load doctors: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    }
  }

  Widget _buildAvailableDoctorsSection(
    BuildContext ctx,
    SupabaseClient client,
    String patientId,
    List<Map<String, dynamic>> assignedDoctors,
    List<Map<String, dynamic>> availableDoctors,
  ) {
    final assignedDoctorIds = assignedDoctors.map((d) => d['doctor_id'].toString()).toSet();
    final unassignedDoctors = availableDoctors.where((d) => !assignedDoctorIds.contains(d['id'].toString())).toList();

    if (unassignedDoctors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'All doctors are already assigned to this patient',
          textAlign: TextAlign.center,
          style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Doctors',
          style: CareTheme.bodySans.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...unassignedDoctors.map((doctor) {
          final doctorId = doctor['id']?.toString() ?? '';
          final doctorName = doctor['name']?.toString() ?? 'Doctor';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: MedicalTheme.primaryTeal.withValues(alpha: 0.1),
                child: Text(
                  doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                  style: const TextStyle(
                    color: MedicalTheme.primaryTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(doctorName),
              subtitle: Text(doctor['email']?.toString() ?? ''),
              trailing: ElevatedButton(
                onPressed: () async {
                  try {
                    await client.from('doctor_patient_mapping').insert({
                      'doctor_id': doctorId,
                      'patient_id': patientId,
                      'caregiver_id': client.auth.currentUser!.id,
                      'status': 'pending',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Doctor assignment request sent'),
                          backgroundColor: MedicalTheme.accentGreen,
                        ),
                      );
                      Navigator.pop(ctx);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to assign doctor: $e'),
                          backgroundColor: MedicalTheme.accentCoral,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Assign'),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedDoctors(SupabaseClient client, String patientId) async {
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
    } catch (e) {
      print('Error fetching assigned doctors: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableDoctors(SupabaseClient client) async {
    try {
      final response = await client
          .from('users')
          .select('id, name, email')
          .eq('role', 'doctor');
    
      return response.map((doc) {
        return {
          'id': doc['id'].toString(),
          'name': doc['name']?.toString() ?? 'Doctor',
          'email': doc['email']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching doctors: $e');
      return [];
    }
  }


  Future<void> _resolveAlert(String alertId) async {
    setState(() {
      _resolvedAlertIds.add(alertId);
      _resolvingAlertId = alertId;
    });
    try {
      await ref.read(supabaseClientProvider).from('emergency_alerts').update({
        'status': 'RESOLVED',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert resolved.'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resolvedAlertIds.remove(alertId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: MedicalTheme.accentCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingAlertId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myPatientsProvider, (prev, next) {
      print('LISTENER DATA: ${next.value}');
      if (next.hasValue && next.value != null && next.value!.isNotEmpty) {
    // Find newest patient by created_at
        final patients = next.value!;
        String? newestId;
        DateTime? newestDate;
        for (var p in patients) {
          final createdAt = DateTime.tryParse(p['created_at']?.toString() ?? '');
          if (createdAt != null && (newestDate == null || createdAt.isAfter(newestDate))) {
            newestDate = createdAt;
            newestId = p['patient_id']?.toString();
          }
        }
        final firstId = newestId ?? patients.first['patient_id']?.toString();
        print('SELECTED PATIENT ID: $firstId');
        if (firstId != null && _selectedPatientId != firstId) {
          setState(() {
            _selectedPatientId = firstId;
          });
          // Invalidate providers for the new patient
          ref.invalidate(todayRemindersProvider(firstId));
          ref.invalidate(caregiverRecentActivityProvider(firstId));
          ref.invalidate(latestPatientStageProvider(firstId));
          ref.invalidate(patientQuestionnaireResponsesProvider(firstId));
          ref.invalidate(memoryPhotosProvider(firstId));
          ref.invalidate(geofenceProvider(firstId));
          ref.invalidate(patientProfileProvider(firstId));
          ref.invalidate(caregiverDailyRoutinesProvider(firstId));
          ref.invalidate(todayDailyRoutinesProvider(firstId));
          ref.invalidate(patientAppointmentsProvider(firstId));
          ref.invalidate(nextAppointmentProvider(firstId));
        }
      } else {
        if (_selectedPatientId != null) {
          setState(() => _selectedPatientId = null);
        }
      }
    });

    final caregiverName = ref.watch(userProfileProvider).value?['name'] ?? 'Caregiver';
    final allActiveAlerts = ref.watch(activeEmergencyAlertsProvider).value ?? [];
    final activeAlerts = allActiveAlerts
        .where((a) => !_resolvedAlertIds.contains(a['id'].toString()))
        .toList();

    final myPatients = ref.watch(myPatientsProvider).value ?? [];
    final pendingInvites = ref.watch(myPendingInvitesProvider).value ?? [];
    
    // Auto-select patient from the list
    final selectedMappings = myPatients.where(
      (m) => m['patient_id']?.toString() == _selectedPatientId,
    );
    final selectedMapping = selectedMappings.isNotEmpty
        ? selectedMappings.first
        : (myPatients.isNotEmpty ? myPatients.first : null);
    final patientId = selectedMapping?['patient_id'] as String?;
    final patientUser = selectedMapping?['users'] as Map<String, dynamic>?;
    final patientName = patientUser?['name'] as String? ?? 'Your loved one';
    final patientSinceYear = () {
      final created = selectedMapping?['created_at']?.toString();
      if (created == null || created.length < 4) return null;
      return created.substring(0, 4);
    }();

    final profileAsync = patientId != null ? ref.watch(patientProfileProvider(patientId)) : null;
    final age = _ageFromDob(profileAsync?.valueOrNull?['date_of_birth']?.toString());
    final emergencyPhone = profileAsync?.valueOrNull?['emergency_contact_phone']?.toString();
    final emergencyName = profileAsync?.valueOrNull?['emergency_contact_name']?.toString();

    final stageAsync = patientId != null ? ref.watch(latestPatientStageProvider(patientId)) : null;
    final latestStage = stageAsync?.valueOrNull;
    final responsesAsync = patientId != null
        ? ref.watch(patientQuestionnaireResponsesProvider(patientId))
        : null;
    final decline = responsesAsync?.valueOrNull != null
        ? _declinePercent(responsesAsync!.value!)
        : 8.0;

    final patientAlerts = patientId == null
        ? activeAlerts
        : activeAlerts.where((a) => a['patient_id']?.toString() == patientId).toList();

    final photosCount = patientId != null
        ? (ref.watch(memoryPhotosProvider(patientId)).valueOrNull?.length ?? 0)
        : 0;
    final geofence = patientId != null ? ref.watch(geofenceProvider(patientId)).valueOrNull : null;
    final geofenceActive = geofence != null && (geofence['is_active'] as bool? ?? true);
    final medicationAdherence = patientId != null 
        ? ref.watch(medicationAdherenceProvider(patientId)).valueOrNull 
        : null;

    final todayReminders = patientId != null
        ? ref.watch(todayRemindersProvider(patientId))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);
    final activityAsync = patientId != null
        ? ref.watch(caregiverRecentActivityProvider(patientId))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);
    final nextAppointmentAsync = patientId != null
        ? ref.watch(nextAppointmentProvider(patientId))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    SystemChrome.setSystemUIOverlayStyle(CareTheme.lightOverlay);

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: Text('CareConnect', style: CareTheme.displaySerif.copyWith(fontSize: 20)),
          actions: [
            NotificationBell(),
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () async {
                await context.push('/caregiver/invite');
                await _refreshAll();
              },
              tooltip: 'Invite Patient',
            ),
            if (patientId != null)
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientProfileFormScreen(patientId: patientId),
                  ),
                ),
              ),
            IconButton(icon: const Icon(Icons.logout_outlined), onPressed: logout),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: CareTheme.accentPink))
            : RefreshIndicator(
                color: CareTheme.accentPink,
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (patientAlerts.isNotEmpty)
                        _EmergencyBanner(
                          alert: patientAlerts.first,
                          resolving: _resolvingAlertId == patientAlerts.first['id'].toString(),
                          onResolve: () => _resolveAlert(patientAlerts.first['id'].toString()),
                        ),

                      if (myPatients.isEmpty) ...[
                        CaregiverLinkBanner(
                          onLink: () async {
                            await context.push('/caregiver/invite');
                            await _refreshAll();
                          },
                        ),
                        if (pendingInvites.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: CaregiverDarkCard(
                              child: Text(
                                'Invite pending for ${pendingInvites.first['patient_email']}',
                                style: CareTheme.bodySans.copyWith(color: CareTheme.warning),
                              ),
                            ),
                          ),
                      ] else ...[
                        _HeaderSection(
                          caregiverName: caregiverName,
                          patientName: patientName,
                          age: age,
                          patientSinceYear: patientSinceYear,
                          dateLabel: _formatHeaderDate(),
                        ),
                        const SizedBox(height: 20),
                        _CognitiveStatusCard(
                          stage: latestStage?['stage']?.toString() ?? 'No stage assigned',
                          declinePercent: decline,
                          lastAssessmentDate: latestStage?['assigned_at']?.toString().substring(0, 10) ??
                              (responsesAsync?.valueOrNull?.isNotEmpty == true
                                  ? responsesAsync!.value!.last['submitted_at']?.toString().substring(0, 10)
                                  : null),
                          onViewTrend: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CognitiveTrendScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _AICareInsightCard(
                          insight: _generateInsight(
                            latestStage?['stage']?.toString(),
                            decline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickStatCard(
                                emoji: '🚨',
                                label: 'Safety Alerts',
                                value: patientAlerts.isEmpty ? 'All clear' : '${patientAlerts.length} active',
                                accent: patientAlerts.isEmpty ? CareTheme.success : CareTheme.error,
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AlertsScreen(records: records),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickStatCard(
                                emoji: '🧠',
                                label: 'Memory Photos',
                                value: '$photosCount',
                                accent: CareTheme.accentPink,
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemoryPhotosScreen(
                                        patientId: patientId!,
                                        isCaregiver: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickStatCard(
                                emoji: '📍',
                                label: 'Safe Zone',
                                value: geofence == null ? 'Not set' : (geofenceActive ? 'Active' : 'Off'),
                                accent: geofenceActive ? CareTheme.success : CareTheme.textMuted,
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GeofenceScreen(patientId: patientId!),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (patientId != null)
                          CaregiverDarkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '💊 Medication Adherence (Last 7 days)',
                                  style: CareTheme.bodySans.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (medicationAdherence == null || medicationAdherence.isEmpty)
                                  Text(
                                    'No medication data available for the last 7 days.',
                                    style: CareTheme.bodySans.copyWith(
                                      fontSize: 13,
                                      color: CareTheme.textMuted,
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 180,
                                    child: BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        maxY: 100,
                                        minY: 0,
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine: (_) => FlLine(
                                            color: CareTheme.surfaceLight,
                                            strokeWidth: 1,
                                          ),
                                        ),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 32,
                                              getTitlesWidget: (v, _) => Text(
                                                '${v.toInt()}%',
                                                style: CareTheme.bodySans.copyWith(fontSize: 10),
                                              ),
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (v, _) {
                                                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                                final i = v.toInt();
                                                if (i < 0 || i >= days.length) {
                                                  return const SizedBox.shrink();
                                                }
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Text(
                                                    days[i],
                                                    style: CareTheme.bodySans.copyWith(fontSize: 11),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          topTitles: const AxisTitles(),
                                          rightTitles: const AxisTitles(),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        barGroups: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final day = entry.value;
                                          final adherence = medicationAdherence?[day] ?? 0.0;
                                          return BarChartGroupData(
                                            x: entry.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: adherence,
                                                color: adherence >= 80
                                                    ? CareTheme.success
                                                    : adherence >= 50
                                                        ? CareTheme.warning
                                                        : CareTheme.error,
                                                width: 16,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (patientId != null) ...[
                          Consumer(
                            builder: (context, ref, _) {
                              final activeConsultAsync = ref.watch(activeConsultationProvider);
                              return activeConsultAsync.when(
                                data: (consultation) {
                                  if (consultation != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: IncomingConsultationCard(
                                        consultation: consultation,
                                        role: 'caregiver',
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                        CaregiverSectionTitle(
                          title: 'Upcoming visits',
                          actionLabel: 'Manage',
                          onAction: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManageAppointmentsScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        nextAppointmentAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (next) {
                            if (next == null) {
                              return CaregiverDarkCard(
                                child: Text(
                                  'No visits scheduled. Tap Manage to add a doctor appointment.',
                                  style: CareTheme.bodySans.copyWith(
                                    fontSize: 13,
                                    color: CareTheme.textMuted,
                                  ),
                                ),
                              );
                            }
                            return AppointmentCard(
                              doctorName: next['doctor_name']?.toString() ?? 'Visit',
                              appointmentType: next['appointment_type']?.toString(),
                              location: next['location']?.toString(),
                              appointmentTimeIso: next['appointment_time']?.toString() ?? '',
                              notes: next['notes']?.toString(),
                              compact: true,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        CaregiverSectionTitle(
                          title: "Today's reminders",
                          actionLabel: 'Manage',
                          onAction: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RemindersScreen(patientId: patientId!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        todayReminders.when(
                          loading: () => const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: CareTheme.accentPink),
                          )),
                          error: (e, _) => Text('Error: $e', style: CareTheme.bodySans),
                          data: (reminders) {
                            if (reminders.isEmpty) {
                              return CaregiverDarkCard(
                                child: Text(
                                  'No reminders scheduled. Tap Manage to add one.',
                                  style: CareTheme.bodySans.copyWith(fontSize: 13, color: CareTheme.textMuted),
                                ),
                              );
                            }
                            return Column(
                              children: reminders.map((r) {
                                final id = r['id'].toString();
                                final done = r['done_today'] == true;
                                return MedicationReminderCard(
                                  title: r['title']?.toString() ?? 'Reminder',
                                  time: _formatTime(r['scheduled_time']?.toString()),
                                  pillImageUrl: r['pill_image_url']?.toString(),
                                  dosage: r['dosage']?.toString(),
                                  instructions: r['instructions']?.toString(),
                                  type: r['type']?.toString(),
                                  done: done,
                                  loading: _loggingReminderIds.contains(id),
                                  onMarkDone: done
                                      ? null
                                      : () => _markReminderDone(patientId!, id),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RemindersScreen(patientId: patientId!),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add new reminder'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManageDailyRoutinesScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.checklist_rounded, size: 20),
                          label: const Text('Edit daily routine checklist'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MoodTrendScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: 20),
                          label: const Text('Mood & energy trends'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManageAppointmentsScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.event_available_outlined, size: 20),
                          label: const Text('Manage appointments & visits'),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionChip(
                                icon: Icons.assignment_outlined,
                                label: 'Questionnaire',
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CaregiverQuestionnaireScreen(
                                        patientId: patientId!,
                                        patientName: patientName,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionChip(
                                icon: Icons.photo_library_outlined,
                                label: 'Memory Photos',
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemoryPhotosScreen(
                                        patientId: patientId!,
                                        isCaregiver: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionChip(
                                icon: Icons.phone_in_talk_outlined,
                                label: 'Emergency',
                                onTap: () => _openWithPatient(
                                  patientId,
                                  () => _showEmergencyContact(emergencyPhone, emergencyName),
                                ),
                              ),
                            ),
                            
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openWithPatient(
                            patientId,
                            () => _showDoctorSelectionSheet(patientId!, patientName),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 20),
                          label: const Text('Message Doctor'),
                        ),
                        const SizedBox(height: 24),
                        CaregiverSectionTitle(
                          title: 'Recent activity',
                          actionLabel: 'View all',
                          onAction: () => _openWithPatient(
                            patientId,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CaregiverActivityLogScreen(
                                  patientId: patientId!,
                                  patientName: patientName,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        activityAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Error: $e'),
                          data: (items) {
                            if (items.isEmpty) {
                              return CaregiverDarkCard(
                                child: Text(
                                  'Activity will appear here as care events are logged.',
                                  style: CareTheme.bodySans.copyWith(fontSize: 13, color: CareTheme.textMuted),
                                ),
                              );
                            }
                            return Column(
                              children: items
                                  .map((item) => CaregiverActivityTile(item: item))
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
String _generateInsight(
  String? stage,
  double declinePercent,
) {
  if (stage == null || stage == 'No stage assigned') {
    return '''
No cognitive assessment available.

Recommendation:
• Complete questionnaire assessment
• Track memory changes weekly
• Generate baseline cognitive score
''';
  }

  if (declinePercent > 30) {
    return '''
Patient shows significant cognitive decline.

Recommendation:
• Schedule doctor consultation
• Increase daily supervision
• Review medication adherence
''';
  }

  if (declinePercent > 15) {
    return '''
Mild cognitive decline detected.

Recommendation:
• Continue routine monitoring
• Repeat assessment next month
''';
  }

  return '''
Patient condition appears stable.

Recommendation:
• Maintain daily activities
• Continue medication schedule
• Reassess periodically
''';
}
// ─────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────

class _EmergencyBanner extends StatelessWidget {
  final dynamic alert;
  final bool resolving;
  final VoidCallback onResolve;

  const _EmergencyBanner({
    required this.alert,
    required this.resolving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CareTheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE ${alert['alert_type'] ?? 'SOS'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Patient: ${alert['patient_name'] ?? 'Unknown'}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CareTheme.error,
              ),
              onPressed: resolving ? null : onResolve,
              child: resolving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('MARK AS RESOLVED', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String caregiverName;
  final String patientName;
  final int? age;
  final String? patientSinceYear;
  final String dateLabel;

  const _HeaderSection({
    required this.caregiverName,
    required this.patientName,
    this.age,
    this.patientSinceYear,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ageText = age != null ? ', $age yrs' : '';
    final sinceText = patientSinceYear != null ? ' · Patient since $patientSinceYear' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $caregiverName',
          style: CareTheme.displaySerif.copyWith(fontSize: 26, color: CareTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(dateLabel, style: CareTheme.bodySans.copyWith(fontSize: 13, color: CareTheme.textMuted)),
        const SizedBox(height: 16),
        CaregiverDarkCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: CareTheme.accentPink.withValues(alpha: 0.2),
                child: const Icon(Icons.person_rounded, color: CareTheme.accentPink, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: CareTheme.bodySans.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: CareTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Caring for$ageText$sinceText',
                      style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CognitiveStatusCard extends StatelessWidget {
  final String stage;
  final double declinePercent;
  final String? lastAssessmentDate;
  final VoidCallback onViewTrend;

  const _CognitiveStatusCard({
    required this.stage,
    required this.declinePercent,
    this.lastAssessmentDate,
    required this.onViewTrend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CareTheme.surface,
            CareTheme.surfaceLight.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CareTheme.accentPink.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_outlined, color: CareTheme.accentPink, size: 28),
              const SizedBox(width: 10),
              Text(
                'Cognitive status',
                style: CareTheme.bodySans.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: CareTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stage,
            style: CareTheme.displaySerif.copyWith(fontSize: 20, color: CareTheme.textPrimary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '6‑month concern trend',
                style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
              ),
              Text(
                '${declinePercent.toStringAsFixed(0)}%',
                style: CareTheme.bodySans.copyWith(
                  fontWeight: FontWeight.w700,
                  color: declinePercent > 30 ? CareTheme.error : CareTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (declinePercent / 100).clamp(0.05, 1.0),
              minHeight: 8,
              backgroundColor: CareTheme.background,
              color: declinePercent > 30 ? CareTheme.error : CareTheme.accentPink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lastAssessmentDate != null
                ? 'Last assessment: $lastAssessmentDate'
                : 'No assessment yet',
            style: CareTheme.bodySans.copyWith(fontSize: 12, color: CareTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onViewTrend, child: const Text('View trend')),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  const _QuickStatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CaregiverDarkCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            label,
            style: CareTheme.bodySans.copyWith(fontSize: 11, color: CareTheme.textMuted),
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: CareTheme.bodySans.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CaregiverDarkCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: CareTheme.accentPink, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: CareTheme.bodySans.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
class _AICareInsightCard extends StatelessWidget {
  final String insight;

  const _AICareInsightCard({
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CareTheme.accentPink.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.auto_awesome,
                color: CareTheme.accentPink,
              ),
              SizedBox(width: 10),
              Text(
                'AI Care Insight',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 15),

          Text(
            insight,
            style: TextStyle(
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
