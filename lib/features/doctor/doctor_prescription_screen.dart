import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/notification_service.dart';

/// Full-screen prescription form — keeps the main dashboard scroll smooth.
class DoctorPrescriptionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorPrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<DoctorPrescriptionScreen> createState() =>
      _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends ConsumerState<DoctorPrescriptionScreen> {
  static const _frequencyOptions = [
    'Once daily',
    'Twice daily',
    'With meals',
    'As needed',
  ];

  final _medNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  String _frequency = _frequencyOptions.first;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _syncReminder = true;
  bool _saving = false;

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<String?> _linkedCaregiverId() async {
    final client = ref.read(supabaseClientProvider);
    final row = await client
        .from('caregiver_patient_mapping')
        .select('caregiver_id')
        .eq('patient_id', widget.patientId)
        .limit(1)
        .maybeSingle();
    return row?['caregiver_id']?.toString();
  }

  Future<void> _save() async {
    if (_medNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a medication name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);

      await client.from('prescriptions').insert({
        'patient_id': widget.patientId,
        'doctor_id': session?.user.id,
        'medication_name': _medNameCtrl.text.trim(),
        'dosage': _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
        'frequency': _frequency,
        'start_date': _startDate.toIso8601String().substring(0, 10),
        'end_date': _endDate?.toIso8601String().substring(0, 10),
        'instructions':
            _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
      });
      // ── 🔔 Notify patient about new prescription ──
      await NotificationService.send(
        userId: widget.patientId,
        title: '💊 New Prescription',
        body: '${_medNameCtrl.text.trim()} — $_frequency. Check your reminders.',
        type: 'prescription',
        data: {'medication': _medNameCtrl.text.trim(), 'frequency': _frequency},
      );

      // ── 🔔 Notify caregiver about new prescription ──
      final caregiverId = await _linkedCaregiverId();
      if (caregiverId != null) {
        await NotificationService.send(
          userId: caregiverId,
          title: '💊 New Prescription for ${widget.patientName}',
          body: '${_medNameCtrl.text.trim()} — $_frequency has been prescribed.',
          type: 'prescription',
          data: {'patient_id': widget.patientId, 'medication': _medNameCtrl.text.trim()},
        );
      }
      if (_syncReminder) {
        final caregiverId = await _linkedCaregiverId();
        if (caregiverId != null) {
          await client.from('scheduled_messages').insert({
            'patient_id': widget.patientId,
            'caregiver_id': caregiverId,
            'title': _medNameCtrl.text.trim(),
            'message': 'Prescribed by clinician — $_frequency',
            'type': 'medication',
            'scheduled_time': '09:00:00',
            'repeat_pattern': 'daily',
            'dosage': _dosageCtrl.text.trim(),
            'instructions': _instructionsCtrl.text.trim(),
            'is_active': true,
          });
          ref.invalidate(scheduledMessagesProvider(widget.patientId));
        }
      }

      ref.invalidate(patientPrescriptionsProvider(widget.patientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Prescription saved.'),
            backgroundColor: CareTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: CareTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: Text('Prescription — ${widget.patientName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _medNameCtrl,
              decoration: const InputDecoration(labelText: 'Medication name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageCtrl,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g. 5mg once daily',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _frequency,
              isExpanded: true,
              dropdownColor: CareTheme.surface,
              iconEnabledColor: CareTheme.textPrimary,
              style: CareTheme.dropdownItemStyle,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: _frequencyOptions
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f, style: CareTheme.dropdownItemStyle),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _startDate = d);
              },
              child: Text('Start date: ${_startDate.toIso8601String().substring(0, 10)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _endDate = d);
              },
              child: Text(
                _endDate == null
                    ? 'End date (optional)'
                    : 'End date: ${_endDate!.toIso8601String().substring(0, 10)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(labelText: 'Instructions'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _syncReminder,
              activeColor: CareTheme.accentPink,
              title: const Text('Sync to caregiver medication reminders'),
              subtitle: const Text(
                'Creates a daily 9:00 AM reminder for the linked caregiver',
                style: TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
              ),
              onChanged: (v) => setState(() => _syncReminder = v ?? true),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
