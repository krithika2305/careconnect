import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import 'widgets/caregiver_ui.dart';

/// Full recent-activity list (reminders, SOS, questionnaires, routines, etc.).
class CaregiverActivityLogScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const CaregiverActivityLogScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(caregiverFullActivityProvider(patientId));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: Text(
            'Activity log',
            style: CareTheme.displaySerif.copyWith(fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: activityAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.accentPink),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No activity logged yet for $patientName.',
                    textAlign: TextAlign.center,
                    style: CareTheme.bodySans.copyWith(color: CareTheme.textMuted),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'All events for $patientName',
                      style: CareTheme.bodySans.copyWith(
                        fontSize: 14,
                        color: CareTheme.textMuted,
                      ),
                    ),
                  );
                }
                return CaregiverActivityTile(item: items[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class CaregiverActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const CaregiverActivityTile({super.key, required this.item});

  IconData get _icon {
    switch (item['type']) {
      case 'medication':
        return Icons.medication_outlined;
      case 'questionnaire':
        return Icons.assignment_turned_in_outlined;
      case 'alert':
        return Icons.notifications_active_outlined;
      case 'routine':
        return Icons.checklist_rounded;
      default:
        return Icons.psychology_outlined;
    }
  }

  String get _formattedTime {
    final timeStr = item['time']?.toString() ?? '';
    if (timeStr.length >= 16) {
      return timeStr.substring(0, 16).replaceFirst('T', ' ');
    }
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    return CaregiverDarkCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: CareTheme.accentPinkSoft, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? 'Activity',
                  style: CareTheme.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (_formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formattedTime,
                    style: CareTheme.bodySans.copyWith(
                      fontSize: 12,
                      color: CareTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
