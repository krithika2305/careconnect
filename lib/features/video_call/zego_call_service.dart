import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'consultation_service.dart';

class ZegoCallService {
  static Future<void> _openMeeting(String roomId) async {
    final url = Uri.parse('https://meet.jit.si/$roomId');

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  static Future<void> startCall(
    BuildContext context,
    SupabaseClient client, {
    required String consultationId,
    required String roomId,
    required String userId,
    required String userName,
    required bool isDoctor,
  }) async {
    print('START CALL');
    print('ROOM ID: $roomId');

    await _openMeeting(roomId);
  }

  static Future<void> joinCall(
    BuildContext context,
    SupabaseClient client, {
    required String consultationId,
    required String roomId,
    required String userId,
    required String userName,
    required String role,
  }) async {
    await ConsultationService.joinConsultation(
      client,
      consultationId,
      role,
    );

    await _openMeeting(roomId);
  }
}