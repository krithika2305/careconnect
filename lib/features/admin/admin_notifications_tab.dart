import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminNotificationsTab extends ConsumerWidget {
  const AdminNotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MedicalTheme.darkSlate,
                    ),
              ),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                onPressed: () => _showCreateNotificationDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Create',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.primaryTeal,
                ),
              ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getNotifications(ref),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading notifications: ${snapshot.error}'));
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 48, color: MedicalTheme.lightSlate),
                      SizedBox(height: 16),
                      Text('No notifications found', style: TextStyle(color: MedicalTheme.lightSlate)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationCard(
                    notification: notification,
                    onDelete: () => _deleteNotification(context, ref, notification['id']),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _getNotifications(WidgetRef ref) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final notifications = await client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      return notifications.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  void _showCreateNotificationDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'info';
    String selectedTarget = 'all';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 12),
                const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'success', child: Text('Success')),
                    DropdownMenuItem(value: 'error', child: Text('Error')),
                  ],
                  onChanged: (value) => setState(() => selectedType = value ?? 'info'),
                ),
                const SizedBox(height: 12),
                const Text('Target Audience:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedTarget,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                    DropdownMenuItem(value: 'caregiver', child: Text('Caregivers')),
                    DropdownMenuItem(value: 'patient', child: Text('Patients')),
                  ],
                  onChanged: (value) => setState(() => selectedTarget = value ?? 'all'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createNotification(
                  context,
                  ref,
                  titleController.text,
                  messageController.text,
                  selectedType,
                  selectedTarget,
                );
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNotification(
    BuildContext context,
    WidgetRef ref,
    String title,
    String message,
    String type,
    String target,
  ) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('notifications').insert({
        'title': title,
        'message': message,
        'type': type,
        'target_audience': target,
        'created_at': DateTime.now().toIso8601String(),
        'read': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(BuildContext context, WidgetRef ref, String notificationId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('notifications').delete().eq('id', notificationId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String? ?? 'info';
    final target = notification['target_audience'] as String? ?? 'all';
    final createdAt = notification['created_at'] as String?;

    Color typeColor;
    IconData typeIcon;
    switch (type.toLowerCase()) {
      case 'warning':
        typeColor = Colors.orange;
        typeIcon = Icons.warning_rounded;
        break;
      case 'success':
        typeColor = MedicalTheme.accentGreen;
        typeIcon = Icons.check_circle_rounded;
        break;
      case 'error':
        typeColor = Colors.red;
        typeIcon = Icons.error_rounded;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.info_rounded;
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] ?? 'No message',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    target.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (_) {
      return 'Unknown';
    }
  }
}
