import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

/// Daily routine checklist for the patient dashboard.
class PatientDailyRoutineSection extends ConsumerStatefulWidget {
  final String patientId;

  const PatientDailyRoutineSection({super.key, required this.patientId});

  @override
  ConsumerState<PatientDailyRoutineSection> createState() =>
      _PatientDailyRoutineSectionState();
}

class _PatientDailyRoutineSectionState
    extends ConsumerState<PatientDailyRoutineSection> {
  final Set<String> _completingIds = {};

  static const _periodOrder = ['morning', 'afternoon', 'evening'];

  String _periodLabel(String period) {
    switch (period) {
      case 'morning':
        return '🌅 Morning';
      case 'afternoon':
        return '☀️ Afternoon';
      case 'evening':
        return '🌙 Evening';
      default:
        return period;
    }
  }

  Future<void> _markDone(String routineId) async {
  setState(() => _completingIds.add(routineId));
  try {
    await ref.read(supabaseClientProvider).from('routine_logs').insert({
      'routine_id': routineId,
      'patient_id': widget.patientId,
      'status': 'completed',
    });
    ref.invalidate(todayDailyRoutinesProvider(widget.patientId));
    // ✅ Force rebuild after invalidation
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Great job — task marked done!'),
          backgroundColor: MedicalTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    // ... error handling
  } finally {
    if (mounted) setState(() => _completingIds.remove(routineId));
  }
}

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(todayDailyRoutinesProvider(widget.patientId));

    return routinesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: MedicalTheme.primaryTeal),
        ),
      ),
      error: (e, _) => Text(
        'Could not load routine: $e',
        style: const TextStyle(color: Colors.white70),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Your caregiver has not set up a daily routine yet.',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
          );
        }

        final doneCount = tasks.where((t) => t['done_today'] == true).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily routine',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$doneCount / ${tasks.length}',
                  style: const TextStyle(
                    color: MedicalTheme.primaryTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: tasks.isEmpty ? 0 : doneCount / tasks.length,
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: MedicalTheme.accentGreen,
              ),
            ),
            const SizedBox(height: 16),
            ..._periodOrder.expand((period) {
              final periodTasks =
                  tasks.where((t) => t['time_of_day'] == period).toList();
              if (periodTasks.isEmpty) return <Widget>[];
              return [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _periodLabel(period),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                ...periodTasks.map((task) {
                  final id = task['id'].toString();
                  final done = task['done_today'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RoutineCheckTile(
                      title: task['task_name']?.toString() ?? 'Task',
                      done: done,
                      loading: _completingIds.contains(id),
                      onDone: done ? null : () => _markDone(id),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ];
            }),
          ],
        );
      },
    );
  }
}

class _RoutineCheckTile extends StatelessWidget {
  final String title;
  final bool done;
  final bool loading;
  final VoidCallback? onDone;

  const _RoutineCheckTile({
    required this.title,
    required this.done,
    this.loading = false,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading || done ? null : onDone,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? MedicalTheme.accentGreen.withValues(alpha: 0.2)
                      : Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? MedicalTheme.accentGreen : Colors.white38,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, color: MedicalTheme.accentGreen, size: 20)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: done ? Colors.white54 : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!done)
                loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: onDone,
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
