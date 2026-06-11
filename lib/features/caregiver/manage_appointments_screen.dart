import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/appointment_card.dart';
import '../shared/appointment_utils.dart';
import '../../services/notification_service.dart';
import '../../services/notification_service.dart';

class ManageAppointmentsScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const ManageAppointmentsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends ConsumerState<ManageAppointmentsScreen> {
  bool _saving = false;

  Future<DateTime?> _pickAppointmentDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: CareTheme.lightTheme,
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
      builder: (context, child) => Theme(
        data: CareTheme.lightTheme,
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showAppointmentDialog({Map<String, dynamic>? existing}) async {
    final doctorController = TextEditingController(text: existing?['doctor_name']?.toString());
    final locationController = TextEditingController(text: existing?['location']?.toString());
    final notesController = TextEditingController(text: existing?['notes']?.toString());
    String selectedType = existing?['appointment_type']?.toString() ?? 'neurologist';
    if (!AppointmentUtils.types.contains(selectedType)) {
      selectedType = 'neurologist';
    }

    var appointmentDt = DateTime.tryParse(existing?['appointment_time']?.toString() ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(days: 1, hours: 10));

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: CareTheme.surface,
              title: Text(
                existing == null ? 'Add appointment' : 'Edit appointment',
                style: CareTheme.displaySerif.copyWith(fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: doctorController,
                      decoration: const InputDecoration(labelText: 'Doctor / provider name *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: CareTheme.surface,
                      iconEnabledColor: CareTheme.textPrimary,
                      style: CareTheme.dropdownItemStyle,
                      decoration: const InputDecoration(labelText: 'Visit type'),
                      items: AppointmentUtils.types
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  AppointmentUtils.typeLabel(t),
                                  style: CareTheme.dropdownItemStyle,
                                ),
                              ))
                          .toList(),
                      selectedItemBuilder: (context) => AppointmentUtils.types
                          .map((t) => Text(
                                AppointmentUtils.typeLabel(t),
                                style: CareTheme.dropdownItemStyle,
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppointmentUtils.formatDateTime(appointmentDt.toUtc().toIso8601String()),
                        style: CareTheme.bodySans.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Tap to change date & time',
                        style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                      ),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final picked = await _pickAppointmentDateTime(initial: appointmentDt);
                        if (picked != null) {
                          setDialogState(() => appointmentDt = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Clinic address or video call',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'What to bring, parking, etc.',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true || doctorController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);
    final payload = {
      'patient_id': widget.patientId,
      'caregiver_id': session?.user.id,
      'doctor_name': doctorController.text.trim(),
      'appointment_type': selectedType,
      'location': locationController.text.trim().isEmpty ? null : locationController.text.trim(),
      'appointment_time': appointmentDt.toUtc().toIso8601String(),
      'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    };

    try {
      if (existing == null) {
        await client.from('appointments').insert(payload);
        // 🔔 Notify the patient about new appointment
        // Get the appointment ID (you may need to query it back, or use the returned data)
        final newId = await client
            .from('appointments')
            .select('id')
            .eq('patient_id', widget.patientId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final appointmentId = newId?['id']?.toString();

        await NotificationService.send(
          userId: widget.patientId,
          title: '📅 New Appointment',
          body: '${doctorController.text.trim()} on ${AppointmentUtils.formatDateTime(appointmentDt.toUtc().toIso8601String())}',
          type: 'appointment',
          data: {
            'appointment_id': appointmentId,
            'doctor_name': doctorController.text.trim(),
            'appointment_time': appointmentDt.toUtc().toIso8601String(),
          },
        );
      } else {
        await client.from('appointments').update(payload).eq('id', existing['id']);
      }
      ref.invalidate(patientAppointmentsProvider(widget.patientId));
      ref.invalidate(allAppointmentsProvider(widget.patientId));
      ref.invalidate(nextAppointmentProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Appointment added' : 'Appointment updated'),
            backgroundColor: CareTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e'), backgroundColor: CareTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAppointment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CareTheme.surface,
        title: const Text('Delete appointment?'),
        content: const Text('This visit will be removed from the schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: CareTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(supabaseClientProvider).from('appointments').delete().eq('id', id);
      ref.invalidate(patientAppointmentsProvider(widget.patientId));
      ref.invalidate(allAppointmentsProvider(widget.patientId));
      ref.invalidate(nextAppointmentProvider(widget.patientId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(allAppointmentsProvider(widget.patientId));

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: Text('Visits — ${widget.patientName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showAppointmentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add visit'),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final upcoming = all.where((a) => AppointmentUtils.isUpcoming(a['appointment_time']?.toString())).toList();
          final past = all.where((a) => !AppointmentUtils.isUpcoming(a['appointment_time']?.toString())).toList();

          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No appointments yet. Tap "Add visit" to schedule a neurologist, primary care, or therapy visit.',
                  textAlign: TextAlign.center,
                  style: CareTheme.bodySans,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              Text(
                'Upcoming',
                style: CareTheme.bodySans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CareTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                Text('No upcoming visits.', style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted))
              else
                ...upcoming.map((a) => GestureDetector(
                      onTap: () => _showAppointmentDialog(existing: a),
                      child: AppointmentCard(
                        doctorName: a['doctor_name']?.toString() ?? 'Visit',
                        appointmentType: a['appointment_type']?.toString(),
                        location: a['location']?.toString(),
                        appointmentTimeIso: a['appointment_time']?.toString() ?? '',
                        notes: a['notes']?.toString(),
                        onDelete: () => _deleteAppointment(a['id'].toString()),
                      ),
                    )),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Past visits',
                  style: CareTheme.bodySans.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CareTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ...past.take(15).map((a) => AppointmentCard(
                      doctorName: a['doctor_name']?.toString() ?? 'Visit',
                      appointmentType: a['appointment_type']?.toString(),
                      location: a['location']?.toString(),
                      appointmentTimeIso: a['appointment_time']?.toString() ?? '',
                      notes: a['notes']?.toString(),
                      compact: true,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}
