import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminDashboardOverviewTab extends ConsumerWidget {
  final TabController tabController;
  
  const AdminDashboardOverviewTab({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading stats: $e')),
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MedicalTheme.darkSlate,
                      ),
                ),
                const SizedBox(height: 20),
                // Stats Grid
                GridView.count(
                    crossAxisCount: _getCrossAxisCount(context),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _getChildAspectRatio(context),
                    children: [
                      _buildStatCard(
                        context,
                        title: 'Total Users',
                        value: stats['total_users']?.toString() ?? '0',
                        icon: Icons.people_alt_rounded,
                        color: MedicalTheme.primaryTeal,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Total Doctors',
                        value: stats['total_doctors']?.toString() ?? '0',
                        icon: Icons.medical_services_rounded,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Total Caregivers',
                        value: stats['total_caregivers']?.toString() ?? '0',
                        icon: Icons.favorite_rounded,
                        color: MedicalTheme.accentPink,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Total Patients',
                        value: stats['total_patients']?.toString() ?? '0',
                        icon: Icons.person_rounded,
                        color: MedicalTheme.accentOrange,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Pending Verifications',
                        value: stats['pending_verifications']?.toString() ?? '0',
                        icon: Icons.pending_actions_rounded,
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Verified Doctors',
                        value: stats['verified_doctors']?.toString() ?? '0',
                        icon: Icons.verified_rounded,
                        color: MedicalTheme.accentGreen,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Verified Caregivers',
                        value: stats['verified_caregivers']?.toString() ?? '0',
                        icon: Icons.verified_user_rounded,
                        color: MedicalTheme.accentGreen,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Suspended Accounts',
                        value: stats['suspended_accounts']?.toString() ?? '0',
                        icon: Icons.block_rounded,
                        color: Colors.red,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Active Accounts',
                        value: stats['active_accounts']?.toString() ?? '0',
                        icon: Icons.check_circle_rounded,
                        color: MedicalTheme.accentGreen,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Emergency Alerts',
                        value: stats['emergency_alerts']?.toString() ?? '0',
                        icon: Icons.warning_rounded,
                        color: Colors.redAccent,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Quick Actions Section
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MedicalTheme.darkSlate,
                      ),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'Review Pending Verifications',
                  subtitle: '${stats['pending_verifications'] ?? 0} requests awaiting review',
                  icon: Icons.fact_check_rounded,
                  color: MedicalTheme.primaryTeal,
                  onTap: () {
                    tabController.animateTo(4); // Navigate to Verification tab (index 4)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'Manage Users',
                  subtitle: 'View and manage all user accounts',
                  icon: Icons.manage_accounts_rounded,
                  color: Colors.blue,
                  onTap: () {
                    tabController.animateTo(1); // Navigate to Users tab (index 1)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'Manage Doctors',
                  subtitle: 'View and manage doctor accounts',
                  icon: Icons.medical_services_rounded,
                  color: Colors.blue,
                  onTap: () {
                    tabController.animateTo(2); // Navigate to Doctors tab (index 2)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'Manage Caregivers',
                  subtitle: 'View and manage caregiver accounts',
                  icon: Icons.favorite_rounded,
                  color: MedicalTheme.accentPink,
                  onTap: () {
                    tabController.animateTo(3); // Navigate to Caregivers tab (index 3)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'Manage Patients',
                  subtitle: 'View and manage patient accounts',
                  icon: Icons.person_rounded,
                  color: MedicalTheme.accentOrange,
                  onTap: () {
                    tabController.animateTo(4); // Navigate to Patients tab (index 4)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'View Analytics',
                  subtitle: 'View system analytics and reports',
                  icon: Icons.analytics_rounded,
                  color: MedicalTheme.primaryTeal,
                  onTap: () {
                    tabController.animateTo(6); // Navigate to Analytics tab (index 6)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'View Notifications',
                  subtitle: 'Manage system notifications',
                  icon: Icons.notifications_rounded,
                  color: MedicalTheme.accentOrange,
                  onTap: () {
                    tabController.animateTo(8); // Navigate to Notifications tab (index 8)
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  context,
                  title: 'View Audit Logs',
                  subtitle: 'Track all admin actions',
                  icon: Icons.history_rounded,
                  color: MedicalTheme.accentOrange,
                  onTap: () {
                    tabController.animateTo(9); // Navigate to Logs tab (index 9)
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 5;
  }

  double _getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2.0;
    if (width < 900) return 2.4;
    return 2.2;
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 14,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 18,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black87,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: MedicalTheme.lightSlate,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
