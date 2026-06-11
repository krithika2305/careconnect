import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/supabase_service.dart';
import 'services/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/patient/patient_dashboard.dart';
import 'features/caregiver/caregiver_dashboard.dart';
import 'features/doctor/doctor_dashboard.dart';
import 'features/admin/admin_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: CareConnectApp()));
}

class CareConnectApp extends StatelessWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareConnect',
      debugShowCheckedModeBanner: false,
      theme: MedicalTheme.lightTheme,
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends ConsumerWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    if (session == null) return const LoginScreen();

    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const RoleSelectionScreen();

        switch (profile['role']?.toString().toLowerCase()) {
          case 'patient':
            return const PatientDashboard();
          case 'caregiver':
            return const CaregiverDashboard();
          case 'doctor':
            return const DoctorDashboard();
          case 'admin':
            return const AdminDashboard();
          default:
            return const RoleSelectionScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading your workspace…',
                style: TextStyle(
                    color: MedicalTheme.lightSlate,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error logging in: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
