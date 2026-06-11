import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/splash_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/onboarding/onboarding_screens.dart';
import '../features/caregiver/invite_loved_one_screen.dart';
import '../features/patient/patient_dashboard.dart';
import '../features/caregiver/caregiver_dashboard.dart';
import '../features/doctor/doctor_dashboard.dart';
import '../features/admin/admin_dashboard.dart';
import '../services/providers.dart';
import '../services/auth_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) => authRedirect(
      ref: ref,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'caregiver';
          final complete = state.uri.queryParameters['complete'] == '1';
          return RegisterScreen(
            initialRole: role,
            forceCompleteProfile: complete,
          );
        },
      ),
      GoRoute(
        path: '/loading',
        redirect: (_, __) => '/role-selection',
      ),

      GoRoute(
        path: '/onboarding/goals',
        builder: (context, state) => const OnboardingGoalsScreen(),
      ),
      GoRoute(
        path: '/onboarding/loved-one',
        builder: (context, state) => const InviteLovedOneScreen(
          showSkip: true,
          successRoute: '/onboarding/notifications',
        ),
      ),
      GoRoute(
        path: '/caregiver/invite',
        builder: (context, state) => const InviteLovedOneScreen(),
      ),
      GoRoute(
        path: '/onboarding/notifications',
        builder: (context, state) => const OnboardingNotificationsScreen(),
      ),
      GoRoute(
        path: '/onboarding/complete',
        builder: (context, state) => const OnboardingCompleteScreen(),
      ),
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientDashboard(),
      ),
      GoRoute(
        path: '/caregiver',
        builder: (context, state) => const CaregiverDashboard(),
      ),
      GoRoute(
        path: '/doctor',
        builder: (context, state) => const DoctorDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
    ],
  );

  // Refresh routing when auth session or profile finishes loading.
  ref.listen(authSessionProvider, (_, __) => router.refresh());
  ref.listen(userProfileProvider, (prev, next) {
    if (next.hasValue && prev?.valueOrNull != next.valueOrNull) {
      router.refresh();
    }
  });

  return router;
});
