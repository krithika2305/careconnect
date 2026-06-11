import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

            Color roleColor;
            switch (role) {
              case 'ADMIN': roleColor = Colors.purple; break;
              case 'DOCTOR': roleColor = Colors.blue; break;
              case 'CAREGIVER': roleColor = MedicalTheme.accentOrange; break;
              case 'PATIENT': roleColor = MedicalTheme.primaryTeal; break;
              default: roleColor = Colors.grey; break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: roleColor),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email),
                    const SizedBox(height: 4),
                    Text('Joined: $createdAt', style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                onTap: () {
                  // In a real app, this would open a user detail/edit screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Manage user: $name')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
