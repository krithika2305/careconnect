import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/notification_service.dart';

class ManageDailyRoutinesScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const ManageDailyRoutinesScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<ManageDailyRoutinesScreen> createState() =>
      _ManageDailyRoutinesScreenState();
}

class _ManageDailyRoutinesScreenState
    extends ConsumerState<ManageDailyRoutinesScreen> {
  static const _periods = ['morning', 'afternoon', 'evening'];

  String _periodLabel(String period) {
    switch (period) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'evening':
        return 'Evening';
      default:
        return period;
    }
  }

  IconData _periodIcon(String period) {
    switch (period) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'afternoon':
        return Icons.wb_cloudy_outlined;
      case 'evening':
        return Icons.nights_stay_outlined;
      default:
        return Icons.checklist_rounded;
    }
  }

  Future<void> _addTask(String timeOfDay) async {
    final controller = TextEditingController();
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CareTheme.surface,
        title: Text('Add ${_periodLabel(timeOfDay)} task',
            style: CareTheme.displaySerif.copyWith(fontSize: 20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Task name',
            hintText: 'e.g. Take morning medication',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (add != true || controller.text.trim().isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);
    try {
      await client.from('daily_routines').insert({
        'patient_id': widget.patientId,
        'caregiver_id': session?.user.id,
        'task_name': controller.text.trim(),
        'time_of_day': timeOfDay,
        'display_order': DateTime.now().millisecondsSinceEpoch % 10000,
        'is_active': true,
      });
      // ── 🔔 Notify patient about new routine task ──
      await NotificationService.send(
        userId: widget.patientId,
        title: '📋 New Daily Routine Task',
        body: 'A new task has been added to your daily routine by your caregiver.',
        type: 'routine',
        data: {'patient_id': widget.patientId},
      );
      ref.invalidate(caregiverDailyRoutinesProvider(widget.patientId));
      ref.invalidate(todayDailyRoutinesProvider(widget.patientId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add task: $e')),
        );
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> task) async {
    final client = ref.read(supabaseClientProvider);
    final active = task['is_active'] as bool? ?? true;
    try {
      await client
          .from('daily_routines')
          .update({'is_active': !active})
          .eq('id', task['id']);
      ref.invalidate(caregiverDailyRoutinesProvider(widget.patientId));
      ref.invalidate(todayDailyRoutinesProvider(widget.patientId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This removes the task from the daily routine.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(supabaseClientProvider).from('daily_routines').delete().eq('id', id);
      ref.invalidate(caregiverDailyRoutinesProvider(widget.patientId));
      ref.invalidate(todayDailyRoutinesProvider(widget.patientId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(caregiverDailyRoutinesProvider(widget.patientId));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: Text(
            'Daily routine',
            style: CareTheme.displaySerif.copyWith(fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: routinesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.accentPink),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allTasks) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Routine for ${widget.patientName}',
                  style: CareTheme.bodySans.copyWith(
                    fontSize: 14,
                    color: CareTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks appear on your loved one\'s checklist by time of day.',
                  style: CareTheme.bodySans.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 20),
                for (final period in _periods) ...[
                  _PeriodHeader(
                    icon: _periodIcon(period),
                    label: _periodLabel(period),
                    onAdd: () => _addTask(period),
                  ),
                  const SizedBox(height: 8),
                  ...allTasks
                      .where((t) => t['time_of_day'] == period)
                      .map((task) => _RoutineManageTile(
                            task: task,
                            onToggle: () => _toggleActive(task),
                            onDelete: () => _deleteTask(task['id'].toString()),
                          )),
                  if (allTasks.where((t) => t['time_of_day'] == period).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 4),
                      child: Text(
                        'No tasks yet. Tap + to add.',
                        style: CareTheme.bodySans.copyWith(
                          fontSize: 12,
                          color: CareTheme.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onAdd;

  const _PeriodHeader({
    required this.icon,
    required this.label,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CareTheme.accentPink, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: CareTheme.bodySans.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline, color: CareTheme.accentPink),
          tooltip: 'Add task',
        ),
      ],
    );
  }
}

class _RoutineManageTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RoutineManageTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = task['is_active'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CareTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? CareTheme.surfaceLight : CareTheme.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              task['task_name']?.toString() ?? 'Task',
              style: CareTheme.bodySans.copyWith(
                decoration: active ? null : TextDecoration.lineThrough,
                color: active ? CareTheme.textPrimary : CareTheme.textMuted,
              ),
            ),
          ),
          Switch(
            value: active,
            activeColor: CareTheme.accentPink,
            onChanged: (_) => onToggle(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: CareTheme.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
