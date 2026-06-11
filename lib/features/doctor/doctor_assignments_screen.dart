import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class DoctorAssignmentsScreen extends ConsumerWidget {
  const DoctorAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(supabaseClientProvider);
    final session = client.auth.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final doctorId = session.user.id;
    final assignmentsAsync = ref.watch(_doctorAssignmentsProvider(doctorId));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: const Text('Patient Assignments'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: assignmentsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.accentPink),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e', style: CareTheme.bodySans),
          ),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_disabled,
                      size: 64,
                      color: CareTheme.textMuted.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No patient assignments',
                      style: CareTheme.bodySans.copyWith(
                        color: CareTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Caregivers will assign patients to you',
                      style: CareTheme.bodySans.copyWith(
                        fontSize: 13,
                        color: CareTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final status = assignment['status']?.toString() ?? 'pending';
                final patientName = assignment['patient_name']?.toString() ?? 'Patient';
                final caregiverName = assignment['caregiver_name']?.toString() ?? 'Caregiver';
                final assignedAt = assignment['assigned_at']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: status == 'accepted'
                                  ? MedicalTheme.accentGreen.withValues(alpha: 0.1)
                                  : status == 'rejected'
                                      ? CareTheme.error.withValues(alpha: 0.1)
                                      : CareTheme.warning.withValues(alpha: 0.1),
                              child: Text(
                                patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                                style: TextStyle(
                                  color: status == 'accepted'
                                      ? MedicalTheme.accentGreen
                                      : status == 'rejected'
                                          ? CareTheme.error
                                          : CareTheme.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patientName,
                                    style: CareTheme.bodySans.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Assigned by $caregiverName',
                                    style: CareTheme.bodySans.copyWith(
                                      fontSize: 12,
                                      color: CareTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'accepted'
                                    ? MedicalTheme.accentGreen.withValues(alpha: 0.1)
                                    : status == 'rejected'
                                        ? CareTheme.error.withValues(alpha: 0.1)
                                        : CareTheme.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: CareTheme.bodySans.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: status == 'accepted'
                                      ? MedicalTheme.accentGreen
                                      : status == 'rejected'
                                          ? CareTheme.error
                                          : CareTheme.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Assigned: ${_formatDate(assignedAt)}',
                          style: CareTheme.bodySans.copyWith(
                            fontSize: 12,
                            color: CareTheme.textMuted,
                          ),
                        ),
                        if (status == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respondToAssignment(
                                    context,
                                    ref,
                                    assignment['id'].toString(),
                                    'accepted',
                                    doctorId,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MedicalTheme.accentGreen,
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respondToAssignment(
                                    context,
                                    ref,
                                    assignment['id'].toString(),
                                    'rejected',
                                    doctorId,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: CareTheme.error,
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _respondToAssignment(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
    String status,
    String doctorId,
  ) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('doctor_patient_mapping')
          .update({'status': status, 'responded_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', assignmentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'accepted' ? 'Assignment accepted' : 'Assignment declined'),
            backgroundColor: status == 'accepted' ? MedicalTheme.accentGreen : CareTheme.error,
          ),
        );
        ref.invalidate(_doctorAssignmentsProvider(doctorId));
        ref.invalidate(doctorPatientsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to respond: $e'),
            backgroundColor: CareTheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return '';
    return iso.substring(0, 10);
  }
}

// Provider for doctor's assignments (including pending)
final _doctorAssignmentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, doctorId) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final mappings = await client
        .from('doctor_patient_mapping')
        .select('id, patient_id, caregiver_id, status, assigned_at')
        .eq('doctor_id', doctorId)
        .order('assigned_at', ascending: false);

    if (mappings.isEmpty) return [];

    final patientIds = mappings.map((m) => m['patient_id'] as String).toList();
    final caregiverIds = mappings.map((m) => m['caregiver_id'] as String).toList();

    final patients = await client
        .from('users')
        .select('id, name')
        .inFilter('id', patientIds);

    final caregivers = await client
        .from('users')
        .select('id, name')
        .inFilter('id', caregiverIds);

    return mappings.map((m) {
      final patient = patients.firstWhere((p) => p['id'] == m['patient_id'], orElse: () => {});
      final caregiver = caregivers.firstWhere((c) => c['id'] == m['caregiver_id'], orElse: () => {});
      return {
        ...Map<String, dynamic>.from(m as Map),
        'patient_name': patient['name']?.toString() ?? 'Patient',
        'caregiver_name': caregiver['name']?.toString() ?? 'Caregiver',
      };
    }).toList();
  } catch (_) {
    return [];
  }
});
