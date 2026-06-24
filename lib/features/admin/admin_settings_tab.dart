import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminSettingsTab extends ConsumerWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MedicalTheme.darkSlate,
                ),
          ),
          const SizedBox(height: 24),
          _SystemSettingsSection(),
          const SizedBox(height: 24),
          _NotificationSettingsSection(),
          const SizedBox(height: 24),
          _SecuritySettingsSection(),
          const SizedBox(height: 24),
          _MaintenanceSection(),
        ],
      ),
    );
  }
}

class _SystemSettingsSection extends ConsumerWidget {
  void _showLanguageDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English (US)'),
              trailing: current == 'en' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Spanish (Español)'),
              trailing: current == 'es' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('es');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('French (Français)'),
              trailing: current == 'fr' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('fr');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Small'),
              trailing: current == 'small' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setFontSize('small');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Medium'),
              trailing: current == 'medium' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setFontSize('medium');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Large'),
              trailing: current == 'large' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setFontSize('large');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Extra Large'),
              trailing: current == 'extra_large' ? const Icon(Icons.check, color: MedicalTheme.primaryTeal) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setFontSize('extra_large');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatLanguage(String code) {
    switch (code) {
      case 'es': return 'Spanish (Español)';
      case 'fr': return 'French (Français)';
      default: return 'English (US)';
    }
  }

  String _formatFontSize(String size) {
    switch (size) {
      case 'small': return 'Small';
      case 'large': return 'Large';
      case 'extra_large': return 'Extra Large';
      default: return 'Medium';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_rounded, color: MedicalTheme.primaryTeal),
                const SizedBox(width: 12),
                Text(
                  'System Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              icon: Icons.language_rounded,
              title: 'App Language',
              subtitle: _formatLanguage(settings.language),
              onTap: () => _showLanguageDialog(context, ref, settings.language),
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: settings.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: 'Dark Mode',
              subtitle: settings.darkMode ? 'Enabled' : 'Disabled',
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDarkMode(!settings.darkMode);
              },
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: Icons.format_size_rounded,
              title: 'Font Size',
              subtitle: _formatFontSize(settings.fontSize),
              onTap: () => _showFontSizeDialog(context, ref, settings.fontSize),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_rounded, color: MedicalTheme.accentOrange),
                const SizedBox(width: 12),
                Text(
                  'Notification Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              context,
              icon: Icons.email_rounded,
              title: 'Email Notifications',
              subtitle: 'Receive email alerts for important events',
              value: settings.emailNotifications,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).setEmailNotifications(value);
              },
            ),
            const Divider(height: 32),
            _buildSwitchTile(
              context,
              icon: Icons.notifications_active_rounded,
              title: 'Push Notifications',
              subtitle: 'Receive push notifications on mobile devices',
              value: settings.pushNotifications,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).setPushNotifications(value);
              },
            ),
            const Divider(height: 32),
            _buildSwitchTile(
              context,
              icon: Icons.warning_rounded,
              title: 'Emergency Alerts',
              subtitle: 'Receive immediate alerts for emergency situations',
              value: settings.emergencyAlerts,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).setEmergencyAlerts(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SecuritySettingsSection extends ConsumerWidget {
  void _showLoginHistoryDialog(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'login_history_$userId';
    final existing = prefs.getStringList(key) ?? [];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Login History'),
        content: SizedBox(
          width: double.maxFinite,
          child: existing.isEmpty
              ? const Text('No login records found.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: existing.length,
                  itemBuilder: (context, index) {
                    final record = jsonDecode(existing[index]) as Map<String, dynamic>;
                    final ts = DateTime.tryParse(record['timestamp'] ?? '');
                    final formattedTime = ts != null 
                        ? '${ts.month}/${ts.day}/${ts.year} at ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : 'N/A';
                    return ListTile(
                      leading: const Icon(Icons.devices_rounded),
                      title: Text(record['user_agent'] ?? 'Unknown device'),
                      subtitle: Text('IP: ${record['ip_address'] ?? 'Unknown'}\nEmail: ${record['email'] ?? ''}'),
                      trailing: Text(formattedTime, style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMfaDialog(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Fetch current factors
    List<dynamic> factors = [];
    try {
      final res = await client.auth.mfa.listFactors();
      factors = res.totp.where((f) => f.status == 'verified').toList();
    } catch (_) {}

    final bool isMfaEnabled = factors.isNotEmpty;

    if (!context.mounted) return;

    if (isMfaEnabled) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Two-Factor Authentication'),
          content: const Text('Two-factor authentication is currently enabled. Would you like to disable it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  for (final f in factors) {
                    await client.auth.mfa.unenroll(f.id);
                  }
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('2FA has been disabled successfully'),
                      backgroundColor: MedicalTheme.accentGreen,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to disable 2FA: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Disable 2FA'),
            ),
          ],
        ),
      );
    } else {
      final totpCodeController = TextEditingController();
      bool isEnrolling = false;
      String? factorId;
      String? secret;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Setup 2FA (TOTP)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (factorId == null) ...[
                    const Text('Step 1: Click "Generate Secret" to begin TOTP enrollment.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isEnrolling
                          ? null
                          : () async {
                              setState(() => isEnrolling = true);
                              try {
                                final enrollment = await client.auth.mfa.enroll(
                                  factorType: FactorType.totp,
                                  issuer: 'CareConnect',
                                );
                                setState(() {
                                  factorId = enrollment.id;
                                  secret = enrollment.totp?.secret;
                                });
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Enrollment error: $e')),
                                );
                              } finally {
                                setState(() => isEnrolling = false);
                              }
                            },
                      child: isEnrolling
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Generate Secret'),
                    ),
                  ] else ...[
                    const Text('Step 2: Copy this TOTP secret into your authenticator app (Google Authenticator, Authy, etc.):'),
                    const SizedBox(height: 8),
                    SelectableText(
                      secret ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MedicalTheme.primaryTeal),
                    ),
                    const SizedBox(height: 16),
                    const Text('Step 3: Enter the 6-digit code from your app to verify:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totpCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Verification Code'),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (factorId != null)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await client.auth.mfa.challengeAndVerify(
                          factorId: factorId!,
                          code: totpCodeController.text.trim(),
                        );
                        Navigator.pop(context);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('2FA setup completed successfully!'),
                            backgroundColor: MedicalTheme.accentGreen,
                          ),
                        );
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Verification failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Verify & Activate'),
                  ),
              ],
            );
          },
        ),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final client = ref.read(supabaseClientProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPasswordController.text.length < 8) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                Navigator.pop(context);
                await client.auth.updateUser(UserAttributes(password: newPasswordController.text));
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully'),
                    backgroundColor: MedicalTheme.accentGreen,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to update password: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: MedicalTheme.accentGreen),
                const SizedBox(width: 12),
                Text(
                  'Security Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              icon: Icons.password_rounded,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () => _showChangePasswordDialog(context, ref),
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: Icons.verified_user_rounded,
              title: 'Two-Factor Authentication',
              subtitle: 'Add an extra layer of security',
              onTap: () => _showMfaDialog(context, ref),
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: Icons.history_rounded,
              title: 'Login History',
              subtitle: 'View recent login activity',
              onTap: () => _showLoginHistoryDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  Future<void> _clearLocalCache(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final language = prefs.getString('language');
      final darkMode = prefs.getBool('darkMode');
      final fontSize = prefs.getString('fontSize');
      final email = prefs.getBool('email_notifications');
      final push = prefs.getBool('push_notifications');
      final emergency = prefs.getBool('emergency_alerts');

      await prefs.clear();

      if (language != null) await prefs.setString('language', language);
      if (darkMode != null) await prefs.setBool('darkMode', darkMode);
      if (fontSize != null) await prefs.setString('fontSize', fontSize);
      if (email != null) await prefs.setBool('email_notifications', email);
      if (push != null) await prefs.setBool('push_notifications', push);
      if (emergency != null) await prefs.setBool('emergency_alerts', emergency);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: MedicalTheme.accentGreen,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _syncData(BuildContext context, WidgetRef ref) {
    ref.invalidate(userProfileProvider);
    ref.invalidate(userNotificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    ref.invalidate(allUsersAdminProvider);
    ref.invalidate(adminDashboardStatsProvider);
    ref.invalidate(myPatientsProvider);
    ref.invalidate(assignedPatientsProvider);
    ref.invalidate(assignedDoctorsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data sync and provider refresh initiated'),
        backgroundColor: MedicalTheme.accentGreen,
      ),
    );
  }

  void _showSystemInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InfoRow('App Version', '1.0.0'),
            const _InfoRow('Build Number', '2'),
            _InfoRow('Platform', Theme.of(context).platform.name),
            _InfoRow('Environment', kDebugMode ? 'Development' : 'Production'),
            const _InfoRow('Database', 'Supabase'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  'Maintenance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              icon: Icons.cleaning_services_rounded,
              title: 'Clear Cache',
              subtitle: 'Clear application cache data',
              onTap: () => _clearLocalCache(context),
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: Icons.sync_rounded,
              title: 'Sync Data',
              subtitle: 'Force sync with server',
              onTap: () => _syncData(context, ref),
            ),
            const Divider(height: 32),
            _buildSettingTile(
              context,
              icon: Icons.info_rounded,
              title: 'System Info',
              subtitle: 'View system information and version',
              onTap: () => _showSystemInfoDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildSettingTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: MedicalTheme.lightSlate),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: MedicalTheme.lightSlate),
        ],
      ),
    ),
  );
}

Widget _buildSwitchTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: MedicalTheme.lightSlate),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: MedicalTheme.primaryTeal,
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: MedicalTheme.lightSlate),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
