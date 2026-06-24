import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/supabase_service.dart';
import 'core/router.dart';
import 'services/providers.dart';

import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'services/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize Supabase for background isolate
      try {
        await SupabaseService.initialize();
      } catch (_) {
        // Already initialized
      }

      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        return Future.value(true);
      }
      final userId = session.user.id;

      // 2. Fetch User Profile & Role
      final userRecord = await supabase
          .from('users')
          .select('role, name')
          .eq('id', userId)
          .maybeSingle();
      if (userRecord == null) {
        return Future.value(true);
      }
      final role = userRecord['role'] as String?;
      final userName = userRecord['name'] as String? ?? 'Patient';

      // 3. Handle Geofencing Check (only if patient)
      if (role == 'patient') {
        final geofence = await supabase
            .from('geofences')
            .select()
            .eq('patient_id', userId)
            .eq('is_active', true)
            .maybeSingle();

        if (geofence != null) {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            final lat = (geofence['latitude'] as num).toDouble();
            final lng = (geofence['longitude'] as num).toDouble();
            final radius = (geofence['radius_meters'] as num).toDouble();

            final distance = Geolocator.distanceBetween(
              lat,
              lng,
              position.latitude,
              position.longitude,
            );

            if (distance > radius) {
              // Patient left the safe zone! Check if alert already exists
              final activeAlerts = await supabase
                  .from('emergency_alerts')
                  .select()
                  .eq('patient_id', userId)
                  .eq('alert_type', 'GEOFENCE_BREACH')
                  .eq('status', 'ACTIVE')
                  .limit(1);

              if (activeAlerts == null || (activeAlerts as List).isEmpty) {
                await supabase.from('emergency_alerts').insert({
                  'patient_id': userId,
                  'patient_name': userName,
                  'alert_type': 'GEOFENCE_BREACH',
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'status': 'ACTIVE',
                  'message': 'Patient has left the safe zone. Current distance: ${distance.toStringAsFixed(1)}m',
                });

                // Fetch linked caregivers to notify them
                final mappings = await supabase
                    .from('caregiver_patient_mapping')
                    .select('caregiver_id')
                    .eq('patient_id', userId);
                if (mappings != null) {
                  for (final m in mappings) {
                    final caregiverId = m['caregiver_id'] as String?;
                    if (caregiverId != null) {
                      await NotificationService.send(
                        userId: caregiverId,
                        title: '🚨 Geofence Breach Alert',
                        body: '$userName has left the safe zone!',
                        type: 'geofence_breach',
                        data: {
                          'patient_id': userId,
                          'distance': distance,
                        },
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 4. Handle Scheduled Reminders
      final reminders = await supabase
          .from('scheduled_messages')
          .select()
          .or('patient_id.eq.$userId,caregiver_id.eq.$userId')
          .eq('is_active', true);

      if (reminders != null && (reminders as List).isNotEmpty) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

        for (final reminder in reminders) {
          final reminderId = reminder['id'] as String;
          final title = reminder['title'] as String? ?? 'Reminder';
          final message = reminder['message'] as String? ?? '';
          final scheduledTimeStr = reminder['scheduled_time'] as String; // "HH:mm:ss"
          final patientId = reminder['patient_id'] as String;

          final timeParts = scheduledTimeStr.split(':');
          final scheduledDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
          );

          if (now.isAfter(scheduledDateTime)) {
            // Check if already delivered today
            final logs = await supabase
                .from('message_logs')
                .select()
                .eq('message_id', reminderId)
                .gte('delivered_at', startOfDay);

            if (logs == null || (logs as List).isEmpty) {
              // Trigger local notification
              const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
                'careconnect_reminders',
                'CareConnect Reminders',
                channelDescription: 'Scheduled reminders for dementia care',
                importance: Importance.max,
                priority: Priority.high,
              );
              const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

              await flutterLocalNotificationsPlugin.show(
                reminderId.hashCode,
                title,
                message,
                platformDetails,
              );

              // Log delivery
              await supabase.from('message_logs').insert({
                'message_id': reminderId,
                'patient_id': patientId,
                'delivered_at': DateTime.now().toUtc().toIso8601String(),
                'status': 'delivered',
              });
              await NotificationService.send(
                userId: reminder['caregiver_id'] as String, 
                title: 'Missed Reminder',
                body: 'Patient missed: ${reminder['title']}',
                type: 'reminder_missed',
                data: {'reminder_id': reminder['id'], 'patient_id': patientId},
              );
            }
          }
        }
      }
    } catch (_) {
      // Return true to avoid blocking background threads on failure
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  // Initialize Notifications
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize Workmanager (only on mobile platforms)
  if (!kIsWeb) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // change to false in production
    );

    // Register Periodic Background Task
    Workmanager().registerPeriodicTask(
      "careconnect_background_task",
      "careconnect_background_task",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  runApp(const ProviderScope(child: CareConnectApp()));
}

class CareConnectApp extends ConsumerWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);

    double fontScale = 1.0;
    if (settings.fontSize == 'small') fontScale = 0.85;
    if (settings.fontSize == 'large') fontScale = 1.15;
    if (settings.fontSize == 'extra_large') fontScale = 1.3;

    return MaterialApp.router(
      title: 'CareConnect',
      debugShowCheckedModeBanner: false,
      theme: CareTheme.lightTheme,
      darkTheme: CareTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: Locale(settings.language),
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
        Locale('fr', ''),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
    );
  }
}

