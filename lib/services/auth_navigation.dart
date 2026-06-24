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

  print('FULL PROFILE: $profile');

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
  final accountStatus = profile['account_status']?.toString();
  final verificationStatus = profile['verification_status']?.toString();

  print('ROLE: $role');
  print('ACCOUNT STATUS: $accountStatus');
  print('VERIFICATION STATUS: $verificationStatus');
  print('ROUTE SHOULD BE: ${routeForRole(role, onboardingDone: true)}');

  // ── Check account status first ──────────────────────────────
  if (accountStatus == 'SUSPENDED') {
    if (!context.mounted) return;
    context.go('/pending-verification?role=$role');
    return;
  }

  // ── Check verification status for doctors & caregivers ──────
  if (role?.toLowerCase() == 'doctor') {
    if (verificationStatus == 'UNVERIFIED') {
      if (!context.mounted) return;
      context.go('/doctor/verify-credentials');
      return;
    }
    if (verificationStatus == 'PENDING_REVIEW' ||
        verificationStatus == 'REJECTED') {
      if (!context.mounted) return;
      context.go('/pending-verification?role=$role');
      return;
    }
  }

  if (role?.toLowerCase() == 'caregiver') {
    if (verificationStatus == 'UNVERIFIED') {
      if (!context.mounted) return;
      context.go('/caregiver/verify-account');
      return;
    }
    if (verificationStatus == 'PENDING_REVIEW' ||
        verificationStatus == 'REJECTED') {
      if (!context.mounted) return;
      context.go('/pending-verification?role=$role');
      return;
    }
  }

  // Patient and admin users should continue to their dashboard even when
  // the database initially defaults account_status = 'PENDING'.
  if (role?.toLowerCase() == 'patient' || role?.toLowerCase() == 'admin') {
    if (!context.mounted) return;
    context.go(routeForRole(role, onboardingDone: true));
    print('NAVIGATING NOW...');
    return;
  }

  if (accountStatus == 'PENDING') {
    if (!context.mounted) return;
    context.go('/pending-verification?role=$role');
    return;
  }

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
  print('REDIRECT CHECK: $location');
  final session = currentAuthSession(ref);
  final isAuth = session != null;

  const publicRoutes = {
    '/splash',
    '/welcome',
    '/about', 
    '/login',
    '/register',
    '/role-selection',
    '/pending-verification',
    '/doctor/verify-credentials',
    '/caregiver/verify-account',
  };
  final isPublic = publicRoutes.contains(location) ||
      location.startsWith('/register') ||
      location.startsWith('/pending-verification') ||
      location.startsWith('/doctor/verify-credentials') ||
      location.startsWith('/caregiver/verify-account');

  if (!isAuth) {
    print('NOT AUTHENTICATED');
    print('IS PUBLIC: $isPublic');
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

  if (profile == null) {
    // No profile and no role in metadata - send to complete profile
    if (location == '/loading') return completeProfileRoute(role: roleFromMetadata);
    final finishingSignup = location == '/role-selection' ||
        location.startsWith('/register') ||
        location == '/login';
    return finishingSignup ? null : completeProfileRoute(role: roleFromMetadata);
  }

  final role = profile['role']?.toString().toLowerCase();
  final accountStatus = profile['account_status']?.toString();
  final verificationStatus = profile['verification_status']?.toString();
  print('CURRENT LOCATION: $location');
  print('ROLE: $role');
  print('VERIFICATION STATUS: $verificationStatus');
  print('ACCOUNT STATUS: $accountStatus');

  // ── Account is SUSPENDED ────────────────────────────────────
  if (accountStatus == 'SUSPENDED') {
    if (isPublic && location == '/pending-verification') return null;
    return '/pending-verification?role=$role';
  }

  

  // ── Doctor verification checks ──────────────────────────────
  if (role == 'doctor') {
    if (verificationStatus == 'UNVERIFIED') {
      if (location == '/doctor/verify-credentials') return null;
      return '/doctor/verify-credentials';
    }
    if (verificationStatus == 'PENDING_REVIEW' ||
        verificationStatus == 'REJECTED') {
      if (location == '/pending-verification') return null;
      return '/pending-verification?role=$role';
    }
    // Doctor is verified - allow dashboard access
    if (location == '/doctor' || isPublic) return null;
    return '/doctor';
  }

  // ── Caregiver verification checks ───────────────────────────
  if (role == 'caregiver') {
    if (verificationStatus == 'UNVERIFIED') {
      if (location == '/caregiver/verify-account') return null;
      return '/caregiver/verify-account';
    }

    if (verificationStatus == 'PENDING_REVIEW' ||
        verificationStatus == 'REJECTED') {
      if (location.startsWith('/pending-verification')) return null;
      return '/pending-verification?role=$role';
    }

    // Allow ALL caregiver routes
    if (location.startsWith('/caregiver') || isPublic) {
      print('ALLOWING CAREGIVER ROUTE');
      return null;
    }

    return '/caregiver';
  }

  // ── Account is PENDING ──────────────────────────────────────
  if (accountStatus == 'PENDING') {
    if (role == 'patient' || role == 'admin') {
      return null;
    }
    if (isPublic && location == '/pending-verification') return null;
    return '/pending-verification?role=$role';
  }

  // ── Patient & Admin (no verification needed) ─────────────────
  if (role == 'patient' || role == 'admin') {
    final targetRoute = routeForRole(role, onboardingDone: true);
    if (location == targetRoute || isPublic) return null;
    return targetRoute;
  }

  return null;
}
