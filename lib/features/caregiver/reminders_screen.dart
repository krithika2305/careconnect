import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/medication_reminder_card.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  final String patientId;

  const RemindersScreen({super.key, required this.patientId});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final _picker = ImagePicker();
  bool _saving = false;

  Future<String?> _uploadPillImage(XFile image) async {
    final client = ref.read(supabaseClientProvider);
    final bytes = await image.readAsBytes();
    final ext = image.path.split('.').last;
    final path = 'pills/${widget.patientId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage.from('careconnect_media').uploadBinary(path, bytes);
    return client.storage.from('careconnect_media').getPublicUrl(path);
  }

  Future<void> _addReminder() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final dosageController = TextEditingController();
    final instructionsController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'medication';
    XFile? pillImage;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMed = selectedType == 'medication';
            return AlertDialog(
              backgroundColor: CareTheme.surface,
              title: Text(
                'Add reminder',
                style: CareTheme.displaySerif.copyWith(fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title / medication name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: CareTheme.surface,
                      iconEnabledColor: CareTheme.textPrimary,
                      style: CareTheme.dropdownItemStyle,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'medication',
                          child: Text('Medication', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        ),
                        DropdownMenuItem(
                          value: 'meal',
                          child: Text('Meal', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        ),
                        DropdownMenuItem(
                          value: 'appointment',
                          child: Text('Appointment', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        ),
                      ],
                      selectedItemBuilder: (context) => const [
                        Text('Medication', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        Text('Meal', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        Text('Appointment', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                        Text('Custom', style: TextStyle(color: CareTheme.textPrimary, fontSize: 16)),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    if (isMed) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          hintText: 'e.g. 1 tablet after breakfast',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                          hintText: 'e.g. Take with water',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setDialogState(() => pillImage = picked);
                          }
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          pillImage == null ? 'Add pill photo' : 'Change pill photo',
                        ),
                      ),
                      if (pillImage != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(pillImage!.path),
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Time: ${selectedTime.format(context)}',
                          style: CareTheme.bodySans,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || titleController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      String? pillUrl;
      if (selectedType == 'medication' && pillImage != null) {
        pillUrl = await _uploadPillImage(pillImage!);
      }

      final formattedTime =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';

      await client.from('scheduled_messages').insert({
        'patient_id': widget.patientId,
        'caregiver_id': client.auth.currentUser!.id,
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'type': selectedType,
        'scheduled_time': formattedTime,
        'repeat_pattern': 'daily',
        if (selectedType == 'medication') ...{
          'dosage': dosageController.text.trim(),
          'instructions': instructionsController.text.trim(),
          if (pillUrl != null) 'pill_image_url': pillUrl,
        },
      });

      ref.invalidate(scheduledMessagesProvider(widget.patientId));
      ref.invalidate(todayRemindersProvider(widget.patientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder saved.'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Bucket not found')
            ? 'Upload failed — run supabase_storage_memory_photos.sql first.'
            : 'Could not save: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: MedicalTheme.accentCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteReminder(String id) async {
    await ref.read(supabaseClientProvider).from('scheduled_messages').delete().eq('id', id);
    ref.invalidate(scheduledMessagesProvider(widget.patientId));
    ref.invalidate(todayRemindersProvider(widget.patientId));
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

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(scheduledMessagesProvider(widget.patientId));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: const Text('Manage Reminders'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _saving ? null : _addReminder,
          backgroundColor: CareTheme.accentPink,
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add),
        ),
        body: remindersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.accentPink),
          ),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (reminders) {
            if (reminders.isEmpty) {
              return Center(
                child: Text(
                  'No scheduled reminders.\nTap + to add medication with a pill photo.',
                  textAlign: TextAlign.center,
                  style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final r = reminders[index];
                return MedicationReminderCard(
                  title: r['title']?.toString() ?? 'Reminder',
                  time: _formatTime(r['scheduled_time']?.toString()),
                  pillImageUrl: r['pill_image_url']?.toString(),
                  dosage: r['dosage']?.toString(),
                  instructions: r['instructions']?.toString(),
                  type: r['type']?.toString(),
                  darkStyle: true,
                  onDelete: () => _deleteReminder(r['id'].toString()),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
