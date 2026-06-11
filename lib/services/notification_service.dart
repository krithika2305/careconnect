import 'dart:convert';
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