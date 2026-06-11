import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminStagesTab extends ConsumerStatefulWidget {
  const AdminStagesTab({super.key});

  @override
  ConsumerState<AdminStagesTab> createState() => _AdminStagesTabState();
}

class _AdminStagesTabState extends ConsumerState<AdminStagesTab> {
  String? _selectedPatientId;
  String _selectedStage = _stageOptions.first;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  static const _stageOptions = [
    'No Cognitive Decline (Normal)',
    'Mild Cognitive Impairment (Very Mild Dementia)',
    'Moderate Cognitive Decline (Mild to Moderate Dementia)',
    'Severe Cognitive Decline (Severe Dementia)',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _assignStage() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a patient first.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);
      await client.from('patient_stages').insert({
        'patient_id': _selectedPatientId,
        'assigned_by': session?.user.id,
        'stage': _selectedStage,
        'stage_notes': _notesCtrl.text.trim(),
      });
      ref.invalidate(patientStagesProvider(_selectedPatientId!));
      ref.invalidate(latestPatientStageProvider(_selectedPatientId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient stage assigned.')),
        );
        _notesCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign stage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersAdminProvider);
    final stagesAsync = _selectedPatientId == null
        ? null
        : ref.watch(patientStagesProvider(_selectedPatientId!));

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (users) {
        final patients = users
            .where((u) => (u['role'] as String?)?.toLowerCase() == 'patient')
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign patient stage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: MedicalTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPatientId,
                      decoration: const InputDecoration(labelText: 'Patient'),
                      items: patients
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                '${p['name'] ?? 'Patient'} (${p['email'] ?? ''})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPatientId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedStage,
                      decoration: const InputDecoration(labelText: 'Stage'),
                      items: _stageOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedStage = v ?? _stageOptions.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _assignStage,
                        child: Text(_saving ? 'Saving…' : 'Activate stage'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Stage history',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: MedicalTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedPatientId == null)
              const Text(
                'Select a patient to view stage history.',
                style: TextStyle(color: MedicalTheme.lightSlate),
              )
            else
              stagesAsync!.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (stages) {
                  if (stages.isEmpty) {
                    return const Text(
                      'No stages assigned yet.',
                      style: TextStyle(color: MedicalTheme.lightSlate),
                    );
                  }
                  return Column(
                    children: stages.map((s) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            s['stage']?.toString() ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (s['stage_notes']?.toString().isNotEmpty == true)
                                s['stage_notes'].toString(),
                              s['assigned_at']?.toString().substring(0, 10) ?? '',
                            ].join('\n'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
