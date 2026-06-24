import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersAdminProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading users: $e')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final role = user['role']?.toString().toUpperCase() ?? 'UNKNOWN';
            final name = user['name'] ?? 'No Name';
            final email = user['email'] ?? 'No Email';
            final createdAt = user['created_at']?.toString().substring(0, 10) ?? 'N/A';
            final accountStatus = user['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
            final verificationStatus = user['verification_status']?.toString().toUpperCase() ?? 'UNKNOWN';

            Color roleColor;
            switch (role) {
              case 'ADMIN': roleColor = Colors.purple; break;
              case 'DOCTOR': roleColor = Colors.blue; break;
              case 'CAREGIVER': roleColor = MedicalTheme.accentOrange; break;
              case 'PATIENT': roleColor = MedicalTheme.primaryTeal; break;
              default: roleColor = Colors.grey; break;
            }

            Color statusColor;
            switch (accountStatus) {
              case 'ACTIVE': statusColor = MedicalTheme.accentGreen; break;
              case 'SUSPENDED': statusColor = Colors.red; break;
              case 'PENDING': statusColor = Colors.orange; break;
              default: statusColor = Colors.grey; break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: roleColor, size: 20),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        email,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: roleColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Joined: $createdAt',
                            style: const TextStyle(
                              fontSize: 10,
                              color: MedicalTheme.lightSlate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            accountStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                    
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) =>
                      _handleMenuAction(context, ref, value, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View User'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit User'),
                    ),
                    const PopupMenuItem(
                      value: 'change_role',
                      child: Text('Change Role'),
                    ),
                  ],
                ),
                onTap: () => _showUserDetails(context, user),
              ),
            );
          },
        );
      },
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, Map<String, dynamic> user) {
    final name = user['name'] ?? 'User';
    final userId = user['id'] as String;

    switch (action) {
      case 'view':
        _showUserDetails(context, user);
        break;
      case 'edit':
        _showEditUserDialog(context, ref, user);
        break;
      case 'change_role':
        _showChangeRoleDialog(context, ref, user);
        break;
      case 'suspend':
        _showConfirmDialog(
          context,
          title: 'Suspend Account',
          content: 'Are you sure you want to suspend $name\'s account?',
          onConfirm: () => _suspendUser(context, ref, userId),
        );
        break;
      case 'activate':
        _showConfirmDialog(
          context,
          title: 'Activate Account',
          content: 'Are you sure you want to activate $name\'s account?',
          onConfirm: () => _activateUser(context, ref, userId),
        );
        break;
      case 'delete':
        _showConfirmDialog(
          context,
          title: 'Delete Account',
          content: 'Are you sure you want to delete $name\'s account? This action cannot be undone.',
          isDestructive: true,
          onConfirm: () => _deleteUser(context, ref, userId),
        );
        break;
    }
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Name', user['name']),
              _detailRow('Email', user['email']),
              _detailRow('Role', user['role']?.toString().toUpperCase()),
              _detailRow('Account Status', user['account_status']?.toString().toUpperCase()),
              _detailRow('Verification Status', user['verification_status']?.toString().toUpperCase()),
              _detailRow('Joined', user['created_at']?.toString().substring(0, 10)),
            ],
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

  void _showEditUserDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUser(context, ref, user['id'], nameController.text, emailController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    String selectedRole = user['role'] as String? ?? 'caregiver';
    final currentRole = selectedRole;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role - ${user['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new role:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
                  DropdownMenuItem(value: 'patient', child: Text('Patient')),
                ],
                onChanged: (value) => setState(() => selectedRole = value ?? 'caregiver'),
              ),
              if (selectedRole == 'doctor' || selectedRole == 'caregiver')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Note: Changing to ${selectedRole.toUpperCase()} will reset verification status to UNVERIFIED.',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selectedRole == currentRole
                ? null
                : () {
                    Navigator.pop(context);
                    _changeUserRole(context, ref, user['id'], selectedRole);
                  },
            child: const Text('Change Role'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : MedicalTheme.primaryTeal,
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendUser(BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('users').update({
        'account_status': 'SUSPENDED',
      }).eq('id', userId);
      
      ref.invalidate(allUsersAdminProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account suspended successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error suspending account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateUser(BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('users').update({
        'account_status': 'ACTIVE',
      }).eq('id', userId);
      
      ref.invalidate(allUsersAdminProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account activated successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('users').delete().eq('id', userId);
      
      ref.invalidate(allUsersAdminProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUser(BuildContext context, WidgetRef ref, String userId, String name, String email) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('users').update({
        'name': name,
        'email': email,
      }).eq('id', userId);
      
      ref.invalidate(allUsersAdminProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeUserRole(BuildContext context, WidgetRef ref, String userId, String newRole) async {
    try {
      final client = ref.read(supabaseClientProvider);
      
      // Prepare update data
      final updateData = <String, dynamic>{'role': newRole};
      
      // Reset verification status for doctor/caregiver
      if (newRole == 'doctor' || newRole == 'caregiver') {
        updateData['verification_status'] = 'UNVERIFIED';
        updateData['account_status'] = 'PENDING';
      } else if (newRole == 'admin') {
        updateData['verification_status'] = 'VERIFIED';
        updateData['account_status'] = 'ACTIVE';
      } else if (newRole == 'patient') {
        updateData['verification_status'] = 'VERIFIED';
        updateData['account_status'] = 'ACTIVE';
      }
      
      await client.from('users').update(updateData).eq('id', userId);
      
      // Update auth metadata
      await client.auth.updateUser(UserAttributes(data: {'role': newRole}));
      
      ref.invalidate(allUsersAdminProvider);
      ref.invalidate(userProfileProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role changed to ${newRole.toUpperCase()} successfully'),
            backgroundColor: MedicalTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, String? value) {
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
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}
