import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/admin_verification_service.dart';

class AdminVerificationTab extends ConsumerStatefulWidget {
  const AdminVerificationTab({super.key});

  @override
  ConsumerState<AdminVerificationTab> createState() =>
      _AdminVerificationTabState();
}

class _AdminVerificationTabState extends ConsumerState<AdminVerificationTab> {
  String _selectedRole = 'all'; // all, doctor, caregiver
  String _selectedStatus = 'pending'; // pending, approved, rejected

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(verificationMetricsProvider);
    final pendingAsync = ref.watch(pendingVerificationsProvider);

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      body: Column(
        children: [
          // ── Metrics Row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: metricsAsync.when(
              loading: () => const SizedBox(height: 100),
              error: (e, _) =>
                  Text('Error loading metrics: $e', style: const TextStyle(color: Colors.red)),
              data: (metrics) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricCard(
                      title: 'Pending',
                      count: metrics['total_pending'] ?? 0,
                      color: MedicalTheme.accentOrange,
                      onTap: () => setState(() => _selectedStatus = 'pending'),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      title: 'Approved',
                      count: metrics['total_approved'] ?? 0,
                      color: MedicalTheme.accentGreen,
                      onTap: () => setState(() => _selectedStatus = 'approved'),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      title: 'Rejected',
                      count: metrics['total_rejected'] ?? 0,
                      color: Colors.red,
                      onTap: () => setState(() => _selectedStatus = 'rejected'),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      title: 'Doctors',
                      count: metrics['pending_doctors'] ?? 0,
                      color: MedicalTheme.primaryTeal,
                      onTap: () => setState(() => _selectedRole = 'doctor'),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      title: 'Caregivers',
                      count: metrics['pending_caregivers'] ?? 0,
                      color: MedicalTheme.accentPink,
                      onTap: () => setState(() => _selectedRole = 'caregiver'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Filters ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    label: 'All',
                    selected: _selectedRole == 'all',
                    onTap: () => setState(() => _selectedRole = 'all'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Doctors',
                    selected: _selectedRole == 'doctor',
                    onTap: () => setState(() => _selectedRole = 'doctor'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Caregivers',
                    selected: _selectedRole == 'caregiver',
                    onTap: () => setState(() => _selectedRole = 'caregiver'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Verification Requests List ──────────────────────────
          Expanded(
            child: pendingAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
              ),
              data: (allRequests) {
                // Filter by role
                var filtered = allRequests;
                if (_selectedRole != 'all') {
                  filtered = filtered
                      .where((r) => r['role'] == _selectedRole)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          size: 48,
                          color: MedicalTheme.accentGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No pending verifications',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final request = filtered[index] as Map<String, dynamic>;
                    final user = request['users'] as Map<String, dynamic>?;
                    final status = request['status'] as String? ?? 'pending';
                    final submittedAt = request['submitted_at'] as String?;

                    return _buildVerificationCard(
                      request: request,
                      user: user,
                      onTap: () =>
                          _showVerificationDetails(context, ref, request),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MedicalTheme.lightSlate,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MedicalTheme.primaryTeal : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? MedicalTheme.primaryTeal : CareTheme.surfaceLight,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : MedicalTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required Map<String, dynamic> request,
    required Map<String, dynamic>? user,
    required VoidCallback onTap,
  }) {
    final role = request['role'] as String? ?? 'user';
    final verifyType = request['verification_type'] as String? ?? 'Unknown';
    final submittedAt = request['submitted_at'] as String?;
    final status = request['status'] as String? ?? 'pending';

    Color statusColor = MedicalTheme.accentOrange;
    if (status == 'approved') statusColor = MedicalTheme.accentGreen;
    if (status == 'rejected') statusColor = Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: role == 'doctor'
                          ? MedicalTheme.primaryTeal.withOpacity(0.1)
                          : MedicalTheme.accentPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        role == 'doctor'
                            ? Icons.medical_services_outlined
                            : Icons.favorite_rounded,
                        color: role == 'doctor'
                            ? MedicalTheme.primaryTeal
                            : MedicalTheme.accentPink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['name'] ?? 'Unknown User',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?['email'] ?? '',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MedicalTheme.lightSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Type: $verifyType',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedicalTheme.lightSlate,
                          ),
                    ),
                  ),
                  if (submittedAt != null)
                    Text(
                      _formatDate(submittedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedicalTheme.lightSlate,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerificationDetails(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) {
    final userId = request['user_id'] as String;
    final role = request['role'] as String? ?? 'user';
    final detailsAsync = ref.watch(userVerificationDetailsProvider(userId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => detailsAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(child: Text('Error: $e')),
        ),
        data: (details) => _buildVerificationDetailSheet(
          context,
          ref,
          request,
          details,
          role,
        ),
      ),
    );
  }

  Widget _buildVerificationDetailSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
    Map<String, dynamic>? details,
    String role,
  ) {
    final user = details?['user'] as Map<String, dynamic>?;
    final credentials =
        details?['credentials'] as Map<String, dynamic>?;
    final caregiverVerif =
        details?['caregiver_verification'] as Map<String, dynamic>?;
    final verificationRequest = details?['verification_request'] as Map<String, dynamic>?;
    final status = request['status'] as String? ?? 'pending';

    // Build documents map from credentials or verification request
    Map<String, dynamic> documents = {};
    
    if (role == 'doctor' && credentials != null) {
      if (credentials['license_document_path'] != null) {
        documents['license_document_url'] = credentials['license_document_path'];
      }
    }
    
    if (role == 'caregiver' && caregiverVerif != null) {
      if (caregiverVerif['certificate_document_path'] != null) {
        documents['id_document_url'] = caregiverVerif['certificate_document_path'];
      }
    }
    
    // Also check verification request for submitted documents
    if (verificationRequest != null && verificationRequest['submitted_documents'] != null) {
      final submittedDocs = verificationRequest['submitted_documents'] as Map<String, dynamic>;
      documents.addAll(submittedDocs);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verification Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildDetailSection('User Information', [
              ('Name', user?['name'] ?? 'N/A'),
              ('Email', user?['email'] ?? 'N/A'),
              ('Role', role.toUpperCase()),
              ('Account Status', user?['account_status'] ?? 'N/A'),
              ('Verification Status', user?['verification_status'] ?? 'N/A'),
              ('Joined', _formatDate(user?['created_at'] ?? '')),
            ]),
            const SizedBox(height: 20),
            if (role == 'doctor' && credentials != null) ...[
              _buildDetailSection('Medical Credentials', [
                ('License Number', credentials['license_number'] ?? 'N/A'),
                ('License State', credentials['license_state'] ?? 'N/A'),
                ('Medical School', credentials['medical_school'] ?? 'N/A'),
                ('Years of Experience', credentials['years_experience']?.toString() ?? 'N/A'),
                ('Specialization', credentials['specialization'] ?? 'N/A'),
                ('Board Certified',
                    credentials['board_certified'] == true ? 'Yes' : 'No'),
                ('Uploaded At', _formatDate(credentials['uploaded_at'] ?? '')),
                ('Verified At', credentials['verified_at'] != null ? _formatDate(credentials['verified_at']) : 'Not verified'),
              ]),
              const SizedBox(height: 20),
            ],
            if (role == 'caregiver' && caregiverVerif != null) ...[
              _buildDetailSection('Caregiver Information', [
                ('Professional Background',
                    caregiverVerif['professional_background'] ?? 'N/A'),
                ('Training Certificate',
                    caregiverVerif['training_certificate'] == true
                        ? 'Yes'
                        : 'No'),
                ('Background Check Status',
                    caregiverVerif['background_check_status'] ?? 'N/A'),
                ('Uploaded At', _formatDate(caregiverVerif['uploaded_at'] ?? '')),
                ('Verified At', caregiverVerif['verified_at'] != null ? _formatDate(caregiverVerif['verified_at']) : 'Not verified'),
              ]),
              const SizedBox(height: 20),
            ],
            if (verificationRequest != null) ...[
              _buildDetailSection('Verification Request', [
                ('Verification Type', verificationRequest['verification_type'] ?? 'N/A'),
                ('Submitted At', _formatDate(verificationRequest['submitted_at'] ?? '')),
                ('Status', verificationRequest['status']?.toUpperCase() ?? 'N/A'),
                if (verificationRequest['reviewed_at'] != null)
                  ('Reviewed At', _formatDate(verificationRequest['reviewed_at'])),
                if (verificationRequest['rejection_reason'] != null)
                  ('Rejection Reason', verificationRequest['rejection_reason']),
              ]),
              const SizedBox(height: 20),
            ],
            if (documents.isNotEmpty) ...[
              _buildDocumentSection(documents),
              const SizedBox(height: 20),
            ],
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _approveVerification(ref, request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            MedicalTheme.accentGreen,
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _rejectVerification(context, ref, request),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      String title, List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MedicalTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    item.$1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MedicalTheme.lightSlate,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.$2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(Map<String, dynamic> documents) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CareTheme.surfaceLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploaded Documents',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...documents.entries.map((entry) {
              final label = _documentLabel(entry.key);
              final url = entry.value?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: url.isNotEmpty
                          ? () => _showDocumentPreview(url)
                          : null,
                      child: const Text('View'),
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

  String _documentLabel(String key) {
    switch (key) {
      case 'license_document_url':
        return 'Doctor License Document';
      case 'id_document_url':
        return 'Caregiver ID Document';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  Future<void> _showDocumentPreview(String documentUrl) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            documentUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to preview document. Please try again later.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approveVerification(
    WidgetRef ref,
    Map<String, dynamic> request,
  ) async {
    try {
      final service = AdminVerificationService(ref.read(supabaseClientProvider));
      final requestId = request['id'] as String;
      final userId = request['user_id'] as String;

      await service.approveDoctorVerification(
        verificationRequestId: requestId,
        userId: userId,
        adminNotes: 'Approved by admin',
      );

      ref.invalidate(pendingVerificationsProvider);
      ref.invalidate(verificationMetricsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectVerification(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Verification'),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final service =
                    AdminVerificationService(ref.read(supabaseClientProvider));
                final requestId = request['id'] as String;
                final userId = request['user_id'] as String;

                await service.rejectVerification(
                  verificationRequestId: requestId,
                  userId: userId,
                  rejectionReason: reasonController.text,
                );

                ref.invalidate(pendingVerificationsProvider);
                ref.invalidate(verificationMetricsProvider);

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification rejected'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}
