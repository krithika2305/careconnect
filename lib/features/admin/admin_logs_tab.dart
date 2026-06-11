import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminLogsTab extends ConsumerWidget {
  const AdminLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminSystemLogsProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading logs: $e')),
      data: (logsData) {
        final alerts = logsData['emergency_alerts'] ?? [];
        final messages = logsData['message_logs'] ?? [];
        final mri = logsData['mri_predictions'] ?? [];

        if (alerts.isEmpty && messages.isEmpty && mri.isEmpty) {
          return const Center(child: Text('No system logs found.'));
        }

        // Combine logs into a single list sorted by timestamp
        final List<Map<String, dynamic>> allLogs = [];
        
        for (var a in alerts) {
          allLogs.add({
            'type': 'Alert',
            'title': 'Emergency: ${a['alert_type']}',
            'subtitle': 'Patient: ${a['patient_name']}',
            'timestamp': a['created_at'],
            'status': a['status'],
          });
        }
        
        for (var m in messages) {
          allLogs.add({
            'type': 'Message',
            'title': 'System Message',
            'subtitle': 'To Patient: ${m['patient_id']}',
            'timestamp': m['delivered_at'],
            'status': m['status'],
          });
        }
        
        for (var p in mri) {
          allLogs.add({
            'type': 'MRI',
            'title': 'MRI Prediction: ${p['prediction']}',
            'subtitle': 'Confidence: ${p['confidence']}%',
            'timestamp': p['created_at'],
            'status': 'LOGGED',
          });
        }

        allLogs.sort((a, b) {
          final timeA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA); // descending
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allLogs.length,
          itemBuilder: (context, index) {
            final log = allLogs[index];
            final type = log['type'];
            
            IconData icon;
            Color color;
            
            if (type == 'Alert') {
              icon = Icons.warning_rounded;
              color = MedicalTheme.accentCoral;
            } else if (type == 'Message') {
              icon = Icons.message_rounded;
              color = MedicalTheme.primaryTeal;
            } else {
              icon = Icons.biotech_rounded;
              color = MedicalTheme.accentOrange;
            }

            final timeStr = log['timestamp']?.toString() ?? '';
            final formattedTime = timeStr.length >= 16 ? timeStr.substring(0, 16).replaceFirst('T', ' ') : 'Unknown Time';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(log['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${log['subtitle']}\n$formattedTime', style: const TextStyle(fontSize: 12)),
                isThreeLine: true,
                trailing: Text(
                  log['status'] ?? '',
                  style: TextStyle(
                    color: log['status'] == 'ACTIVE' ? MedicalTheme.accentCoral : MedicalTheme.lightSlate,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
