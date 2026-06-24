import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminPatientsTab extends ConsumerWidget {
  const AdminPatientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersAdminProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading patients: $e')),
      data: (users) {
        final patients = users
            .where((u) => (u['role'] as String?)?.toLowerCase() == 'patient')
            .toList();

        if (patients.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 48, color: MedicalTheme.lightSlate),
                SizedBox(height: 16),
                Text('No patients found', style: TextStyle(color: MedicalTheme.lightSlate)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _PatientCard(
              patient: patient,
              onUpdateStage: () => _updatePatientStage(context, ref, patient),
              onAssignDoctor: () => _assignDoctor(context, ref, patient),
              onAssignCaregiver: () => _assignCaregiver(context, ref, patient),
              onSuspend: () => _suspendPatient(context, ref, patient),
            );
          },
        );
      },
    );
  }

  void _updatePatientStage(BuildContext context, WidgetRef ref, Map<String, dynamic> patient) {
    final stageController = TextEditingController();
    String selectedStage = _stageOptions.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Update Stage - ${patient['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStage,
                decoration: const InputDecoration(labelText: 'Select Stage'),
                items: _stageOptions
                    .map((stage) => DropdownMenuItem(value: stage, child: Text(stage)))
                    .toList(),
                onChanged: (value) => setState(() => selectedStage = value ?? _stageOptions.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _savePatientStage(context, ref, patient['id'], selectedStage, stageController.text);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _assignDoctor(BuildContext context, WidgetRef ref, Map<String, dynamic> patient) async {
    final client = ref.read(supabaseClientProvider);
    
    try {
      final doctors = await client
          .from('users')
          .select('id, name, email')
          .eq('role', 'doctor')
          .eq('account_status', 'ACTIVE');
      
      if (!context.mounted) return;
      
      String? selectedDoctorId;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Assign Doctor - ${patient['name']}'),
            content: doctors.isEmpty
                ? const Text('No doctors available')
                : DropdownButtonFormField<String>(
                    value: selectedDoctorId,
                    decoration: const InputDecoration(labelText: 'Select Doctor'),
                    items: doctors
                        .map((doctor) => DropdownMenuItem<String>(
                              value: doctor['id'] as String,
                              child: Text('${doctor['name']} (${doctor['email']})'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedDoctorId = value),
                    hint: const Text('Select a doctor'),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedDoctorId != null
                    ? () {
                        Navigator.pop(context);
                        _saveDoctorAssignment(context, ref, patient['id'], selectedDoctorId!);
                      }
                    : null,
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _assignCaregiver(BuildContext context, WidgetRef ref, Map<String, dynamic> patient) async {
    try {
      final client = ref.read(supabaseClientProvider);
      
      // Get all caregivers
      final caregivers = await client
          .from('users')
          .select('id, name, email')
          .eq('role', 'caregiver')
          .eq('account_status', 'ACTIVE');
      
      if (!context.mounted) return;
      
      String? selectedCaregiverId;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Assign Caregiver - ${patient['name']}'),
            content: caregivers.isEmpty
                ? const Text('No caregivers available')
                : DropdownButtonFormField<String>(
                    value: selectedCaregiverId,
                    decoration: const InputDecoration(labelText: 'Select Caregiver'),
                    items: caregivers
                        .map((caregiver) => DropdownMenuItem<String>(
                              value: caregiver['id'] as String,
                              child: Text('${caregiver['name']} (${caregiver['email']})'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedCaregiverId = value),
                    hint: const Text('Select a caregiver'),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedCaregiverId != null
                    ? () {
                        Navigator.pop(context);
                        _saveCaregiverAssignment(context, ref, patient['id'], selectedCaregiverId!);
                      }
                    : null,
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading caregivers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _suspendPatient(BuildContext context, WidgetRef ref, Map<String, dynamic> patient) {
    final accountStatus = patient['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accountStatus == 'ACTIVE' ? 'Suspend Account' : 'Activate Account'),
        content: Text('Are you sure you want to ${accountStatus == 'ACTIVE' ? 'suspend' : 'activate'} ${patient['name']}\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updatePatientStatus(context, ref, patient['id'], accountStatus == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accountStatus == 'ACTIVE' ? Colors.orange : MedicalTheme.accentGreen,
            ),
            child: Text(accountStatus == 'ACTIVE' ? 'Suspend' : 'Activate', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatientStage(BuildContext context, WidgetRef ref, String patientId, String stage, String notes) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);
      
      await client.from('patient_stages').insert({
        'patient_id': patientId,
        'assigned_by': session?.user.id,
        'stage': stage,
        'stage_notes': notes.trim(),
      });
      
      ref.invalidate(patientStagesProvider(patientId));
      ref.invalidate(latestPatientStageProvider(patientId));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient stage updated successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDoctorAssignment(BuildContext context, WidgetRef ref, String patientId, String doctorId) async {
    print('ASSIGNING DOCTOR');
    print('PATIENT ID: $patientId');
    print('DOCTOR ID: $doctorId');
    try {
      final client = ref.read(supabaseClientProvider);
      
      // Check if assignment already exists
      final existing = await client
          .from('doctor_patient_mapping')
          .select()
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .maybeSingle();
      
      if (existing != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doctor already assigned to this patient'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Query caregiver ID linked to the patient
      final caregiverMapping = await client
          .from('caregiver_patient_mapping')
          .select('caregiver_id')
          .eq('patient_id', patientId)
          .limit(1)
          .maybeSingle();
      final caregiverId = caregiverMapping?['caregiver_id'] as String?;
      final adminId = client.auth.currentUser?.id;

      final payload = {
        'patient_id': patientId,
        'doctor_id': doctorId,
        'status': 'accepted',
        'assigned_at': DateTime.now().toIso8601String(),
      };
      if (caregiverId != null) {
        payload['caregiver_id'] = caregiverId;
      } else if (adminId != null) {
        payload['caregiver_id'] = adminId;
      }
      
      final result = await client.from('doctor_patient_mapping').insert(payload).select();
      print('INSERT RESULT: $result');

      // Refresh providers as required by PROBLEM 5
      ref.invalidate(myPatientsProvider);
      ref.invalidate(patientProfileProvider(patientId));
      ref.invalidate(assignedPatientsProvider(doctorId));
      ref.invalidate(assignedDoctorsProvider(patientId));
      ref.invalidate(doctorPatientsProvider);
      ref.invalidate(allUsersAdminProvider);
      ref.invalidate(adminDashboardStatsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor assigned successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      print('DOCTOR ASSIGN ERROR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning doctor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCaregiverAssignment(BuildContext context, WidgetRef ref, String patientId, String caregiverId) async {
    print('ASSIGNING CAREGIVER');
    print('CAREGIVER ID: $caregiverId');
    print('PATIENT ID: $patientId');
    try {
      final client = ref.read(supabaseClientProvider);
      
      // Check if assignment already exists
      final existing = await client
          .from('caregiver_patient_mapping')
          .select()
          .eq('patient_id', patientId)
          .eq('caregiver_id', caregiverId)
          .maybeSingle();
      
      if (existing != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Caregiver already assigned to this patient'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final result = await client.from('caregiver_patient_mapping').insert({
        'patient_id': patientId,
        'caregiver_id': caregiverId,
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      
      print('CAREGIVER INSERT RESULT: $result');

      // Refresh providers as required by PROBLEM 5
      ref.invalidate(myPatientsProvider);
      ref.invalidate(patientProfileProvider(patientId));
      ref.invalidate(allUsersAdminProvider);
      ref.invalidate(adminDashboardStatsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caregiver assigned successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning caregiver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePatientStatus(BuildContext context, WidgetRef ref, String patientId, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('users').update({
        'account_status': status,
      }).eq('id', patientId);
      
      ref.invalidate(allUsersAdminProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient ${status.toLowerCase()} successfully'),
            backgroundColor: status == 'ACTIVE' ? MedicalTheme.accentGreen : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating patient status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static const _stageOptions = [
    'No Cognitive Decline (Normal)',
    'Mild Cognitive Impairment (Very Mild Dementia)',
    'Moderate Cognitive Decline (Mild to Moderate Dementia)',
    'Severe Cognitive Decline (Severe Dementia)',
  ];
}

class _PatientCard extends ConsumerWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onUpdateStage;
  final VoidCallback onAssignDoctor;
  final VoidCallback onAssignCaregiver;
  final VoidCallback onSuspend;

  const _PatientCard({
    required this.patient,
    required this.onUpdateStage,
    required this.onAssignDoctor,
    required this.onAssignCaregiver,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountStatus = patient['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    
    Color statusColor;
    switch (accountStatus) {
      case 'ACTIVE': statusColor = MedicalTheme.accentGreen; break;
      case 'SUSPENDED': statusColor = Colors.red; break;
      case 'PENDING': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: MedicalTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: MedicalTheme.primaryTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['name'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        patient['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MedicalTheme.lightSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    accountStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>?>(
              future: _getPatientDetails(ref, patient['id']),
              builder: (context, snapshot) {
                final stage = snapshot.data?['stage'] ?? 'Not assigned';
                final doctorName = snapshot.data?['doctor_name'] ?? 'Not assigned';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Current Stage', stage, MedicalTheme.accentOrange),
                    _buildInfoRow('Assigned Doctor', doctorName, Colors.blue),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onUpdateStage,
                  icon: const Icon(Icons.timeline_rounded, size: 16),
                  label: const Text('Update Stage'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MedicalTheme.accentOrange),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAssignDoctor,
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Assign Doctor'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAssignCaregiver,
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text('Assign Caregiver'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MedicalTheme.accentPink),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onSuspend,
                  icon: Icon(
                    accountStatus == 'ACTIVE' ? Icons.block_rounded : Icons.check_circle_rounded,
                    size: 16,
                  ),
                  label: Text(accountStatus == 'ACTIVE' ? 'Suspend' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accountStatus == 'ACTIVE' ? Colors.orange : MedicalTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getPatientDetails(WidgetRef ref, String patientId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      
      // Get latest stage
      final stage = await client
          .from('patient_stages')
          .select('stage')
          .eq('patient_id', patientId)
          .order('assigned_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      // Get assigned doctor
      final mapping = await client
          .from('doctor_patient_mapping')
          .select('doctor_id')
          .eq('patient_id', patientId)
          .eq('status', 'accepted')
          .maybeSingle();
      
      String? doctorName;
      if (mapping != null) {
        final doctor = await client
            .from('users')
            .select('name')
            .eq('id', mapping['doctor_id'])
            .maybeSingle();
        doctorName = doctor?['name'] as String?;
      }
      
      return {
        'stage': stage?['stage'],
        'doctor_name': doctorName,
      };
    } catch (_) {
      return null;
    }
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: MedicalTheme.lightSlate,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
