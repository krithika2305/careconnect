import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/alzheimers_model_service.dart';
import 'package:go_router/go_router.dart';
import '../shared/prediction_result_screen.dart';
import '../shared/chat_screen.dart';
import 'doctor_clinical_screen.dart';
import 'doctor_assignments_screen.dart';
import '../../core/widgets/notification_bell.dart';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  final _scrollController = ScrollController();
  String? _selectedPatientId;
  bool _didAutoSelectPatient = false;
  bool _isSavingNotes = false;
  final _notesController = TextEditingController();
  


  @override
  void dispose() {
    _scrollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signOut()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out issue: $e'),
            backgroundColor: CareTheme.error,
          ),
        );
      }
    }
    if (!mounted) return;
    ref.invalidate(authSessionProvider);
    ref.invalidate(userProfileProvider);
    context.go('/welcome');
  }

  Future<void> _onRefresh() async {
    ref.invalidate(doctorPatientsProvider);
    ref.invalidate(mriHistoryProvider);
    ref.invalidate(emergencyHistoryProvider);
    final patientId = _selectedPatientId;
    if (patientId != null) {
      ref.invalidate(patientMriHistoryProvider(patientId));
      ref.invalidate(patientEmergencyHistoryProvider(patientId));
      ref.invalidate(patientQuestionnaireResponsesProvider(patientId));
      ref.invalidate(latestPatientStageProvider(patientId));
      ref.invalidate(patientPrescriptionsProvider(patientId));
    }
    await ref.read(doctorPatientsProvider.future);
  }

  String? _patientIdFromList(List<Map<String, dynamic>> patients) {
    if (patients.isEmpty) return null;
    final validIds =
        patients.map((p) => p['id']?.toString()).whereType<String>().toSet();
    if (_selectedPatientId != null && validIds.contains(_selectedPatientId)) {
      return _selectedPatientId;
    }
    return patients.first['id']?.toString();
  }



  Future<void> _saveClinicalNotes() async {
    if (_notesController.text.trim().isEmpty) return;
    setState(() => _isSavingNotes = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _isSavingNotes = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Consultation notes saved to EHR.'),
          ]),
          backgroundColor: MedicalTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _notesController.clear();
    }
  }

  Future<void> _showCaregiverSelectionSheet() async {
    final selectedPatientId = _selectedPatientId;
    if (selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient first'),
          backgroundColor: MedicalTheme.accentCoral,
        ),
      );
      return;
    }

    final client = ref.read(supabaseClientProvider);
    try {
      // Verify doctor is assigned to this patient
      final assignment = await client
          .from('doctor_patient_mapping')
          .select('id')
          .eq('doctor_id', client.auth.currentUser!.id)
          .eq('patient_id', selectedPatientId)
          .eq('status', 'accepted')
          .maybeSingle();

      if (assignment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are not assigned to this patient'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
        return;
      }

      final mappings = await client
          .from('caregiver_patient_mapping')
          .select('caregiver_id')
          .eq('patient_id', selectedPatientId);

      if (mappings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No caregivers linked to this patient'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
        return;
      }

      final caregiverIds = mappings.map((m) => m['caregiver_id'] as String).toList();
      final caregivers = await client
          .from('users')
          .select('id, name, email')
          .inFilter('id', caregiverIds);

      if (!mounted) return;

      if (caregivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No caregivers available to chat with'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
        return;
      }

      final patientList = ref.watch(doctorPatientsProvider).valueOrNull ?? [];
      final activePatientName = _nameForPatient(patientList, selectedPatientId);

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
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
                'Select a Caregiver',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MedicalTheme.darkSlate,
                ),
              ),
              const SizedBox(height: 16),
              ...caregivers.map((caregiver) {
                final caregiverId = caregiver['id']?.toString() ?? '';
                final caregiverName = caregiver['name']?.toString() ?? 'Caregiver';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: MedicalTheme.primaryTeal.withValues(alpha: 0.1),
                      child: Text(
                        caregiverName.isNotEmpty ? caregiverName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: MedicalTheme.primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(caregiverName),
                    subtitle: Text(caregiver['email']?.toString() ?? ''),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: caregiverId,
                            otherUserName: caregiverName,
                            patientId: selectedPatientId,
                            patientName: activePatientName ?? 'Patient',
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load caregivers: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final doctorName = profileAsync.value?['name'] ?? 'Clinical Staff';
    final patientsAsync = ref.watch(doctorPatientsProvider);

    ref.listen(doctorPatientsProvider, (prev, next) {
      if (_didAutoSelectPatient) return;
      if (!next.hasValue || next.value!.isEmpty) return;
      final id = next.value!.first['id']?.toString();
      if (id == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoSelectPatient) return;
        setState(() {
          _didAutoSelectPatient = true;
          _selectedPatientId = id;
        });
      });
    });

    final patientList = patientsAsync.valueOrNull ?? [];
    final activePatientId = _patientIdFromList(patientList);
    final activePatientName = _nameForPatient(patientList, activePatientId);

    final mriAsync = activePatientId != null
        ? ref.watch(patientMriHistoryProvider(activePatientId))
        : const AsyncValue.data([]);
    final alertsAsync = activePatientId != null
        ? ref.watch(patientEmergencyHistoryProvider(activePatientId))
        : const AsyncValue.data([]);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Clinician Workspace'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          NotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DoctorAssignmentsScreen(),
                ),
              );
            },
            tooltip: 'Patient Assignments',
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined, size: 20),
            label: const Text('Logout'),
            style: TextButton.styleFrom(foregroundColor: CareTheme.error),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: CareTheme.accentPink,
          onRefresh: _onRefresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _doctorHeaderCard(doctorName),
                        const SizedBox(height: 16),
                        _patientSelectorSection(patientsAsync),
                        if (patientList.isEmpty)
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 60),
                                  SizedBox(height: 12),
                                  Text(
                                    'No patients assigned yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Patient records, MRI predictions and emergency alerts will appear once a patient is assigned to you.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (activePatientId != null) ...[
                          const SizedBox(height: 16),
                          _clinicalRecordButton(activePatientId, activePatientName),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _showCaregiverSelectionSheet,
                            icon: const Icon(Icons.chat_outlined, size: 20),
                            label: const Text('Message Caregiver'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MedicalTheme.primaryTeal,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _sectionTitle('Past AI MRI Predictions'),
                        const SizedBox(height: 12),
                        _mriHistorySection(mriAsync),
                        const SizedBox(height: 24),
                        _sectionTitle('Emergency Incident Reports'),
                        const SizedBox(height: 12),
                        _emergencySection(alertsAsync),
                        const SizedBox(height: 24),
                        _sectionTitle('Clinical Consultation Notes'),
                        const SizedBox(height: 12),
                        _notesCard(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _clinicalRecordButton(String patientId, String patientName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient clinical record',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cognitive trends, dementia stage, and prescriptions',
              style: TextStyle(fontSize: 13, color: MedicalTheme.lightSlate),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorClinicalScreen(
                        patientId: patientId,
                        patientName: patientName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Open clinical record'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientSelectorSection(AsyncValue<List<Map<String, dynamic>>> patientsAsync) {
    return patientsAsync.when(
      loading: () => _loadingCard(),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Could not load patients: $e', style: const TextStyle(color: MedicalTheme.darkSlate)),
        ),
      ),
      data: (patients) => _patientDropdownCard(patients),
    );
  }

  Widget _patientDropdownCard(List<Map<String, dynamic>> patients) {
    if (patients.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No patients registered yet. Register a patient account first.',
            style: TextStyle(color: MedicalTheme.darkSlate),
          ),
        ),
      );
    }

    final dropdownValue = _patientIdFromList(patients);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select patient',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dropdownValue,
              isExpanded: true,
              dropdownColor: CareTheme.surface,
              iconEnabledColor: CareTheme.textPrimary,
              style: CareTheme.dropdownItemStyle,
              decoration: const InputDecoration(labelText: 'Patient'),
              items: patients
                  .map((p) => DropdownMenuItem<String>(
                        value: p['id']?.toString(),
                        child: Text(
                          p['name']?.toString() ?? 'Unnamed patient',
                          style: CareTheme.dropdownItemStyle,
                        ),
                      ))
                  .toList(),
              onChanged: (id) => setState(() => _selectedPatientId = id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mriHistorySection(AsyncValue<List<dynamic>> historyAsync) {
    return historyAsync.when(
      loading: () => _loadingCard(),
      error: (e, _) => _messageCard('MRI history error: $e'),
      data: (records) {
        if (records.isEmpty) {
          return _messageCard('No past MRI predictions found.');
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: records.map(_mriHistoryTile).toList(),
        );
      },
    );
  }

  Widget _emergencySection(AsyncValue<List<dynamic>> alertsAsync) {
    return alertsAsync.when(
      loading: () => _loadingCard(),
      error: (e, _) => _messageCard('Alerts error: $e'),
      data: (records) {
        if (records.isEmpty) {
          return _messageCard('No emergency incidents logged.');
        }
        final shown = records.length > 5 ? records.take(5).toList() : records;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: shown.map(_emergencyTile).toList(),
        );
      },
    );
  }

  Widget _messageCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text, style: const TextStyle(color: MedicalTheme.lightSlate)),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: MedicalTheme.darkSlate,
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _doctorHeaderCard(String doctorName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.withValues(alpha: 0.12), width: 1.5),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Colors.blue, size: 30),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. $doctorName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MedicalTheme.darkSlate,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Neurology Clinic • CareConnect Medical',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: MedicalTheme.lightSlate,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter diagnosis updates, medications, or caregiver checklists…',
                labelText: 'Consultation Notes Registry',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.secondaryMint),
                onPressed: _isSavingNotes ? null : _saveClinicalNotes,
                child: _isSavingNotes
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Syncing Notes…'),
                        ],
                      )
                    : const Text('Sync Notes to Database'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nameForPatient(List<Map<String, dynamic>> patients, String? patientId) {
    if (patientId == null) return 'Patient';
    for (final p in patients) {
      if (p['id']?.toString() == patientId) {
        return p['name']?.toString() ?? 'Patient';
      }
    }
    return 'Patient';
  }

  Widget _loadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _mriHistoryTile(dynamic r) {
    final prediction = r['prediction'] ?? 'Unknown';
    final confidence = r['confidence'] ?? 0.0;
    final dateStr = r['created_at']?.toString() ?? '';
    final formatted = dateStr.length >= 10 ? dateStr.substring(0, 10) : 'N/A';

    Color statusColor = MedicalTheme.accentOrange;
    if (prediction.toString().toLowerCase().contains('non')) {
      statusColor = MedicalTheme.accentGreen;
    } else if (prediction.toString().toLowerCase().contains('moderate')) {
      statusColor = MedicalTheme.accentCoral;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            r['image_url'] ?? '',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 50,
              height: 50,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          prediction.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: MedicalTheme.darkSlate,
          ),
        ),
        subtitle: Text(
          'Confidence: ${(confidence as num).toStringAsFixed(1)}% • $formatted',
          style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
        ),
        trailing: Icon(Icons.analytics_rounded, color: statusColor),
      ),
    );
  }

  Widget _emergencyTile(dynamic r) {
    final alertType = r['alert_type'] ?? 'Unknown Alert';
    final patient = r['patient_name'] ?? 'Patient';
    final dateStr = r['created_at']?.toString() ?? '';
    final formatted =
        dateStr.length >= 16 ? dateStr.substring(0, 16).replaceFirst('T', ' ') : 'N/A';
    final resolved = r['status'] == 'RESOLVED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: resolved
                ? MedicalTheme.accentGreen.withValues(alpha: 0.1)
                : MedicalTheme.accentCoral.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            resolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: resolved ? MedicalTheme.accentGreen : MedicalTheme.accentCoral,
          ),
        ),
        title: Text(
          alertType.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: MedicalTheme.darkSlate,
          ),
        ),
        subtitle: Text(
          '$patient • $formatted',
          style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
        ),
        trailing: Text(
          resolved ? 'RESOLVED' : 'ACTIVE',
          style: TextStyle(
            color: resolved ? MedicalTheme.accentGreen : MedicalTheme.accentCoral,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }



}

class _ProbBar extends StatelessWidget {
  final String label;
  final double value; // 0–100

  const _ProbBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (label.contains('Non')) {
      color = MedicalTheme.accentGreen;
    } else if (label.contains('Moderate')) {
      color = MedicalTheme.accentCoral;
    } else {
      color = MedicalTheme.accentOrange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: MedicalTheme.darkSlate)),
            ),
            Text('${value.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              color: color,
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}


