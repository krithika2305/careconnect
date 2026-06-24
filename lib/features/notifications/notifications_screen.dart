import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _markAsRead(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
    ref.invalidate(userNotificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      backgroundColor: CareTheme.background,
      body: notificationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),

        error: (e, _) =>
            Center(child: Text('Error: $e')),

        data: (notifications) {
          print('========== SCREEN DEBUG ==========');
          print('SCREEN COUNT: ${notifications.length}');
          print('SCREEN NOTIFICATIONS: $notifications');

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications yet.'),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (ctx, i) {
              final n = notifications[i];
              final isRead = n['is_read'] == true;
              print('NOTIFICATION DISPLAYED: ${n['title']}');

              return ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : Colors.blue,
                ),
                title: Text(
                  n['title'] ?? '',
                  style: TextStyle(
                    fontWeight: isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Text(n['body'] ?? ''),
                trailing: Text(
                  _formatDate(n['created_at']),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _markAsRead(n['id']),
              );
            },
          );
        },
      ),
    );
  }
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.hour}:${dt.minute}';
  }
}