import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminAnalyticsTab extends ConsumerWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersAdminProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading analytics: $e')),
      data: (users) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MedicalTheme.darkSlate,
                    ),
              ),
              const SizedBox(height: 24),
              _UsersByRoleChart(users: users.cast<Map<String, dynamic>>()),
              const SizedBox(height: 24),
              _RegistrationsByMonthChart(users: users.cast<Map<String, dynamic>>()),
              const SizedBox(height: 24),
              _PatientsByStageChart(ref: ref),
              const SizedBox(height: 24),
              _VerificationRequestsChart(ref: ref),
            ],
          ),
        );
      },
    );
  }
}

class _UsersByRoleChart extends StatelessWidget {
  final List<Map<String, dynamic>> users;

  const _UsersByRoleChart({required this.users});

  @override
  Widget build(BuildContext context) {
    final roleCounts = <String, int>{};
    for (final user in users) {
      final role = user['role'] as String? ?? 'unknown';
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }

    final totalUsers = users.length;
    final maxCount = roleCounts.values.isEmpty ? 1 : roleCounts.values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users by Role',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...roleCounts.entries.map((entry) {
              final percentage = totalUsers > 0 ? (entry.value / totalUsers * 100).toStringAsFixed(1) : '0.0';
              final barWidth = maxCount > 0 ? (entry.value / maxCount) : 0.0;
              
              Color barColor;
              switch (entry.key.toLowerCase()) {
                case 'doctor':
                  barColor = Colors.blue;
                  break;
                case 'caregiver':
                  barColor = MedicalTheme.accentPink;
                  break;
                case 'patient':
                  barColor = MedicalTheme.primaryTeal;
                  break;
                case 'admin':
                  barColor = Colors.purple;
                  break;
                default:
                  barColor = Colors.grey;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text('$percentage% (${entry.value})'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: MedicalTheme.lightSlate.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RegistrationsByMonthChart extends StatelessWidget {
  final List<Map<String, dynamic>> users;

  const _RegistrationsByMonthChart({required this.users});

  @override
  Widget build(BuildContext context) {
    final monthCounts = <String, int>{};
    final now = DateTime.now();
    
    for (final user in users) {
      final createdAt = user['created_at'];
      if (createdAt != null) {
        try {
          final date = DateTime.parse(createdAt);
          if (date.year == now.year) {
            final monthKey = '${date.month}/${date.year}';
            monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
          }
        } catch (_) {}
      }
    }

    // Sort by month
    final sortedMonths = monthCounts.keys.toList()..sort();
    final maxCount = monthCounts.values.isEmpty ? 1 : monthCounts.values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrations by Month (${now.year})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (sortedMonths.isEmpty)
              const Text('No registration data available for this year')
            else
              ...sortedMonths.map((month) {
                final count = monthCounts[month] ?? 0;
                final barWidth = maxCount > 0 ? (count / maxCount) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(month),
                          Text('$count registrations'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barWidth,
                          backgroundColor: MedicalTheme.lightSlate.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(MedicalTheme.primaryTeal),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PatientsByStageChart extends ConsumerWidget {
  final WidgetRef ref;

  const _PatientsByStageChart({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, int>>(
      future: _getPatientStages(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final stageCounts = snapshot.data ?? {};
        final totalPatients = stageCounts.values.fold(0, (sum, count) => sum + count);
        final maxCount = stageCounts.values.isEmpty ? 1 : stageCounts.values.reduce((a, b) => a > b ? a : b);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patients by Stage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (stageCounts.isEmpty)
                  const Text('No patient stage data available')
                else
                  ...stageCounts.entries.map((entry) {
                    final percentage = totalPatients > 0 ? (entry.value / totalPatients * 100).toStringAsFixed(1) : '0.0';
                    final barWidth = maxCount > 0 ? (entry.value / maxCount) : 0.0;
                    
                    Color barColor;
                    if (entry.key.contains('Severe')) {
                      barColor = Colors.red;
                    } else if (entry.key.contains('Moderate')) {
                      barColor = Colors.orange;
                    } else if (entry.key.contains('Mild')) {
                      barColor = MedicalTheme.accentOrange;
                    } else {
                      barColor = MedicalTheme.accentGreen;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('$percentage% (${entry.value})'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: barWidth,
                              backgroundColor: MedicalTheme.lightSlate.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _getPatientStages(WidgetRef ref) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final stages = await client
          .from('patient_stages')
          .select('stage');
      
      final stageCounts = <String, int>{};
      for (final stage in stages) {
        final stageName = stage['stage'] as String? ?? 'Unknown';
        stageCounts[stageName] = (stageCounts[stageName] ?? 0) + 1;
      }
      return stageCounts;
    } catch (_) {
      return {};
    }
  }
}

class _VerificationRequestsChart extends ConsumerWidget {
  final WidgetRef ref;

  const _VerificationRequestsChart({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, int>>(
      future: _getVerificationStats(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        final totalRequests = stats.values.fold(0, (sum, count) => sum + count);
        final maxCount = stats.values.isEmpty ? 1 : stats.values.reduce((a, b) => a > b ? a : b);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (stats.isEmpty)
                  const Text('No verification data available')
                else
                  ...stats.entries.map((entry) {
                    final percentage = totalRequests > 0 ? (entry.value / totalRequests * 100).toStringAsFixed(1) : '0.0';
                    final barWidth = maxCount > 0 ? (entry.value / maxCount) : 0.0;
                    
                    Color barColor;
                    switch (entry.key.toLowerCase()) {
                      case 'pending':
                        barColor = Colors.orange;
                        break;
                      case 'approved':
                        barColor = MedicalTheme.accentGreen;
                        break;
                      case 'rejected':
                        barColor = Colors.red;
                        break;
                      default:
                        barColor = Colors.grey;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text('$percentage% (${entry.value})'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: barWidth,
                              backgroundColor: MedicalTheme.lightSlate.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _getVerificationStats(WidgetRef ref) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final requests = await client
          .from('user_verification_requests')
          .select('status');
      
      final stats = <String, int>{};
      for (final request in requests) {
        final status = request['status'] as String? ?? 'unknown';
        final statusKey = status == 'pending' ? 'Pending' 
                        : status == 'approved' ? 'Approved' 
                        : status == 'rejected' ? 'Rejected' 
                        : 'Unknown';
        stats[statusKey] = (stats[statusKey] ?? 0) + 1;
      }
      return stats;
    } catch (_) {
      return {};
    }
  }
}
