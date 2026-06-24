import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final supabase = Supabase.instance.client;

  static Future<void> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = supabase.auth.currentUser?.id;

      // If the target is the logged-in user, we check their specific preferences.
      if (userId == currentUserId) {
        final pushEnabled = prefs.getBool('push_notifications') ?? true;
        final emergencyEnabled = prefs.getBool('emergency_alerts') ?? true;

        final isEmergency = type.contains('emergency') || 
                            type.contains('sos') || 
                            type.contains('breach') || 
                            type.contains('alert');

        if (isEmergency && !emergencyEnabled) {
          print('NOTIFICATION FILTER RESULT: blocked (emergency alerts disabled for user $userId)');
          return;
        }
        if (!isEmergency && !pushEnabled) {
          print('NOTIFICATION FILTER RESULT: blocked (push notifications disabled for user $userId)');
          return;
        }
      }

      print('NOTIFICATION CREATED: $title');
      print('NOTIFICATION TARGET: $userId');

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data != null ? jsonEncode(data) : null,
        'is_read': false,
      });
    } catch (e) {
      print('Failed to send notification: $e');
    }
  }
}