import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers.dart';
import 'patient_link_service.dart';
import 'user_profile_service.dart';

Session? currentAuthSession(Ref ref) {
  ref.watch(authStateProvider);
  return ref.read(supabaseClientProvider).auth.currentSession;
}

/// One fast profile fetch via RPC (safe even when RLS is misconfigured).
Future<Map<String, dynamic>?> fetchUserProfile(
  SupabaseClient client,
  String userId, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    return await UserProfileService(client).fetch(userId).timeout(timeout);
  } catch (_) {
    return null;
  }
}

String routeForRole(String? role, {required bool onboardingDone}) {
  switch (role?.toLowerCase()) {
    case 'patient':
      return '/patient';
    case 'caregiver':
      return '/caregiver';
    case 'doctor':
      return '/doctor';
    case 'admin':
      return '/admin';
    default:
      return '/role-selection';
  }
}

/// Logged-in user with no public.users row — send to profile completion.
String completeProfileRoute({String? role}) {
  final fallbackRole = role ?? 'caregiver';
  return '/register?role=$fallbackRole&complete=1';
}

/// Routes the user to the correct screen after login or registration.
Future<void> navigateAfterAuth(WidgetRef ref, BuildContext context) async {
  final session = ref.read(supabaseClientProvider).auth.currentSession;
  if (session == null) {
    if (context.mounted) context.go('/welcome');
    return;
  }

  final client = ref.read(supabaseClientProvider);
  var profile = await fetchUserProfile(client, session.user.id);

  if (profile == null) {
    if (!context.mounted) return;
    // Try to get role from auth metadata if available
    final metadata = session.user.userMetadata;
    final roleFromMetadata = metadata?['role'] as String?;
    context.go(completeProfileRoute(role: roleFromMetadata));
    return;
  }

  ref.invalidate(userProfileProvider);

  final role = profile['role']?.toString();

  if (role?.toLowerCase() == 'patient') {
    unawaited(Future(() async {
      await PatientLinkService.acceptPendingInvites(client);
      ref.invalidate(myPatientsProvider);
    }));
  }

  if (!context.mounted) return;
  context.go(routeForRole(role, onboardingDone: true));
}

String? authRedirect({
  required Ref ref,
  required String location,
}) {
  final session = currentAuthSession(ref);
  final isAuth = session != null;

  const publicRoutes = {
    '/splash',
    '/welcome',
    '/login',
    '/register',
    '/role-selection',
  };
  final isPublic =
      publicRoutes.contains(location) || location.startsWith('/register');

  if (!isAuth) {
    return isPublic ? null : '/welcome';
  }

  final profileAsync = ref.read(userProfileProvider);

  if (location == '/splash') {
    if (profileAsync.isLoading && !profileAsync.hasValue) return null;
  }

  final profile = profileAsync.hasValue ? profileAsync.value : null;

  // Check auth metadata first - this is the source of truth for role
  final metadata = session.user.userMetadata;
  final roleFromMetadata = metadata?['role'] as String?;
  final roleLower = roleFromMetadata?.toLowerCase();

  // If auth metadata has a role, use it as the primary source
  if (roleLower != null) {
    if (roleLower == 'doctor') {
      // Doctor goes directly to dashboard, bypassing everything
      if (location != '/doctor') return '/doctor';
      return null;
    }
    if (roleLower == 'admin') {
      if (location != '/admin') return '/admin';
      return null;
    }
    if (roleLower == 'patient') {
      if (location != '/patient') return '/patient';
      return null;
    }
  }

  if (profile == null) {
    // No profile and no role in metadata - send to complete profile
    if (location == '/loading') return completeProfileRoute(role: roleFromMetadata);
    final finishingSignup = location == '/role-selection' ||
        location.startsWith('/register') ||
        location == '/login';
    return finishingSignup ? null : completeProfileRoute(role: roleFromMetadata);
  }

  final role = profile['role']?.toString().toLowerCase();
  
  // Send directly to dashboard, bypassing all onboarding logic
  if (role == 'doctor' || role == 'admin' || role == 'patient' || role == 'caregiver') {
    if (isPublic || location == '/loading' || location.startsWith('/onboarding')) {
      return routeForRole(role, onboardingDone: true);
    }
    return null;
  }

  return null;
}
