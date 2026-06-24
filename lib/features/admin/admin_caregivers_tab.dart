import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminCaregiversTab extends ConsumerWidget {
  const AdminCaregiversTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersAdminProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading caregivers: $e')),
      data: (users) {
        final caregivers = users
            .where((u) => (u['role'] as String?)?.toLowerCase() == 'caregiver')
            .toList();

        if (caregivers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded, size: 48, color: MedicalTheme.lightSlate),
                SizedBox(height: 16),
                Text('No caregivers found', style: TextStyle(color: MedicalTheme.lightSlate)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: caregivers.length,
          itemBuilder: (context, index) {
            final caregiver = caregivers[index];
            return _CaregiverCard(
              caregiver: caregiver,
              onViewVerification: () =>
                  _showCaregiverVerification(
                      context, ref, caregiver),

              onViewPatients: () =>
                  _showAssignedPatients(
                      context, ref, caregiver),

              onApprove: () =>
                  _approveCaregiver(
                      context, ref, caregiver),

              onReject: () =>
                  _rejectCaregiver(
                      context, ref, caregiver),

              onSuspend: () =>
                  _suspendCaregiver(
                      context, ref, caregiver),
            );
          },
        );
      },
    );
  }

  void _showCaregiverVerification(BuildContext context, WidgetRef ref, Map<String, dynamic> caregiver) async {
    final client = ref.read(supabaseClientProvider);
    
    try {
      final verification = await client
          .from('caregiver_verification')
          .select()
          .eq('user_id', caregiver['id'])
          .maybeSingle();

      final request = await client
          .from('user_verification_requests')
          .select()
          .eq('user_id', caregiver['id'])
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!context.mounted) return;

      Map<String, dynamic> submittedDocs = {};
      if (request != null && request['submitted_documents'] != null) {
        final rawDocs = request['submitted_documents'];
        if (rawDocs is Map) {
          submittedDocs = Map<String, dynamic>.from(rawDocs);
        }
      }

      final idCardUrl = verification?['certificate_document_path'] ?? submittedDocs['id_document_url'];
      final trainingCertUrl = submittedDocs['training_certificate_url'] ?? verification?['certificate_document_path'];
      final backgroundDocUrl = submittedDocs['background_verification_url'] ?? submittedDocs['background_check_document_url'];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${caregiver['name']} - Verification'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Name', caregiver['name']),
                _detailRow('Email', caregiver['email']),
                _detailRow('Verification Status', caregiver['verification_status']?.toString().toUpperCase()),
                _detailRow('Account Status', caregiver['account_status']?.toString().toUpperCase()),
                const Divider(height: 32),
                if (verification != null) ...[
                  _detailRow('Background Check Status', verification['background_check_status']),
                  _detailRow('Professional Background', verification['professional_background']),
                  _detailRow(
                    'Training Certificate',
                    verification['training_certificate'] == true
                        ? 'Yes'
                        : 'No',
                  ),
                  _detailRow('Uploaded At', _formatDate(verification['uploaded_at'])),
                  _detailRow('Verified At', verification['verified_at'] != null ? _formatDate(verification['verified_at']) : 'Not verified'),
                ] else ...[
                  const Text('No verification found', style: TextStyle(color: MedicalTheme.lightSlate)),
                ],
                const Divider(height: 32),
                const Text(
                  'Verification Documents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildDocumentRow(context, 'ID Card', idCardUrl),
                _buildDocumentRow(context, 'Training Certificate', trainingCertUrl),
                _buildDocumentRow(context, 'Background Verification Document', backgroundDocUrl),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDocumentRow(BuildContext context, String label, dynamic urlValue) {
    final url = urlValue?.toString();
    final hasDoc = url != null && url.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                if (!hasDoc)
                  const Text(
                    'No document uploaded',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (hasDoc) ...[
            IconButton(
              icon: const Icon(Icons.visibility_rounded, color: MedicalTheme.primaryTeal),
              tooltip: 'Preview',
              onPressed: () => _previewDocument(context, url),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: CareTheme.accentPinkSoft),
              tooltip: 'Download',
              onPressed: () => _downloadDocument(context, url),
            ),
          ],
        ],
      ),
    );
  }

  void _previewDocument(BuildContext context, String url) {
    print('DOCUMENT PREVIEW OPENED');

    final fullUrl = url.startsWith('http') 
        ? url 
        : Supabase.instance.client.storage.from('careconnect_media').getPublicUrl(url);

    final isPdf = fullUrl.toLowerCase().contains('.pdf');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Document Preview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Center(
                  child: isPdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 80, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'PDF Document Preview',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'PDF files cannot be viewed directly inside the app. Open in browser or download to view.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(fullUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.open_in_browser_rounded),
                              label: const Text('Open in Browser'),
                            ),
                          ],
                        )
                      : InteractiveViewer(
                          child: Image.network(
                            fullUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'Unable to preview document.\n$error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadDocument(BuildContext context, String url) async {
    final fullUrl = url.startsWith('http') 
        ? url 
        : Supabase.instance.client.storage.from('careconnect_media').getPublicUrl(url);
    final uri = Uri.parse(fullUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download document: $e')),
      );
    }
  }

  void _showAssignedPatients(BuildContext context, WidgetRef ref, Map<String, dynamic> caregiver) async {
    final client = ref.read(supabaseClientProvider);
    
    try {
      final links = await client
          .from('caregiver_patient_mapping')
          .select()
          .eq('caregiver_id', caregiver['id']);

      if (!context.mounted) return;

      if (links.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${caregiver['name']} - Assigned Patients'),
            content: const Text('No patients assigned to this caregiver'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

     // Get patient details
      print('LINKS: $links');

      final patientIds =
          links.map((l) => l['patient_id'].toString()).toList();

      print('PATIENT IDS: $patientIds');
      final patients = await client
          .from('users')
          .select('id, name, email')
          .inFilter('id', patientIds);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${caregiver['name']} - Assigned Patients (${patients.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final link = links.firstWhere((l) => l['patient_id'] == patient['id']);
                return ListTile(
                  title: Text(patient['name'] ?? 'Unknown'),
                  subtitle: Text(patient['email'] ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MedicalTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ASSIGNED',
                      style: TextStyle(
                        fontSize: 11,
                        color: MedicalTheme.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _suspendCaregiver(BuildContext context, WidgetRef ref, Map<String, dynamic> caregiver) {
    final accountStatus = caregiver['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accountStatus == 'ACTIVE' ? 'Suspend Account' : 'Activate Account'),
        content: Text('Are you sure you want to ${accountStatus == 'ACTIVE' ? 'suspend' : 'activate'} ${caregiver['name']}\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateCaregiverStatus(context, ref, caregiver['id'], accountStatus == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accountStatus == 'ACTIVE' ? Colors.orange : MedicalTheme.accentGreen,
            ),
            child: Text(accountStatus == 'ACTIVE' ? 'Suspend' : 'Activate', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Future<void> _approveCaregiver(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> caregiver,
  ) async {
    try {
      final client =
          ref.read(supabaseClientProvider);

      await client
          .from('users')
          .update({
        'verification_status': 'VERIFIED',
        'account_status': 'ACTIVE',
        'verification_completed_at':
            DateTime.now().toIso8601String(),
      })
          .eq('id', caregiver['id']);

      ref.invalidate(allUsersAdminProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Caregiver approved'),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }
  Future<void> _rejectCaregiver(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> caregiver,
  ) async {
    try {
      final client =
          ref.read(supabaseClientProvider);

      await client
          .from('users')
          .update({
        'verification_status': 'REJECTED',
        'account_status': 'SUSPENDED',
      })
          .eq('id', caregiver['id']);

      ref.invalidate(allUsersAdminProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Caregiver rejected'),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }
  Future<void> _updateCaregiverStatus(
    BuildContext context,
    WidgetRef ref,
    String caregiverId,
    String status,
  ) async {
    try {
      print('UPDATING CAREGIVER');
      print('ID: $caregiverId');
      print('NEW STATUS: $status');

      final client = ref.read(supabaseClientProvider);

      final currentUser = client.auth.currentUser;

      print('CURRENT ADMIN ID: ${currentUser?.id}');
      print('CURRENT ADMIN EMAIL: ${currentUser?.email}');
      print('TARGET CAREGIVER ID: $caregiverId');

      print('ACTIVATE BUTTON CLICKED');
      print('CAREGIVER ID: $caregiverId');

      final before = await client
          .from('users')
          .select('id,email,verification_status,account_status')
          .eq('id', caregiverId);

      print('BEFORE UPDATE: $before');
      final result = await client
          .from('users')
          .update({
            'account_status': status,
          })
          .eq('id', caregiverId)
          .select();

      print('UPDATE RESULT: $result');

      final after = await client
          .from('users')
          .select('id,email,verification_status,account_status')
          .eq('id', caregiverId);

      print('AFTER UPDATE: $after');
      
      ref.invalidate(allUsersAdminProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Caregiver ${status.toLowerCase()} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      print('UPDATE ERROR: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

class _CaregiverCard extends ConsumerWidget {
  final Map<String, dynamic> caregiver;
  final VoidCallback onViewVerification;
  final VoidCallback onViewPatients;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;

  const _CaregiverCard({
    required this.caregiver,
    required this.onViewVerification,
    required this.onViewPatients,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountStatus = caregiver['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final verificationStatus = caregiver['verification_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    
    Color statusColor;
    switch (accountStatus) {
      case 'ACTIVE': statusColor = MedicalTheme.accentGreen; break;
      case 'SUSPENDED': statusColor = Colors.red; break;
      case 'PENDING': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey; break;
    }

    Color verificationColor;
    switch (verificationStatus) {
      case 'VERIFIED': verificationColor = MedicalTheme.accentGreen; break;
      case 'REJECTED': verificationColor = Colors.red; break;
      case 'PENDING_REVIEW': verificationColor = Colors.orange; break;
      default: verificationColor = Colors.grey; break;
    }

    return FutureBuilder<int>(
      future: _getAssignedPatientCount(ref, caregiver['id']),
      builder: (context, snapshot) {
        final patientCount = snapshot.data ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: MedicalTheme.accentPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: MedicalTheme.accentPink,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caregiver['name'] ?? 'Unknown Caregiver',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            caregiver['email'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MedicalTheme.lightSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge('Status', accountStatus, statusColor),
                    const SizedBox(width: 8),
                    _buildStatusBadge('Verification', verificationStatus, verificationColor),
                    const Spacer(),
                    _buildInfoBadge('Patients', patientCount.toString(), MedicalTheme.primaryTeal),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onViewVerification,
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('View Verification'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MedicalTheme.accentPink),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onViewPatients,
                      icon: const Icon(Icons.people_rounded, size: 16),
                      label: const Text('View Patients'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MedicalTheme.primaryTeal),
                      ),
                    ),
                    if (verificationStatus == 'PENDING_REVIEW')
                      ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    if (verificationStatus == 'PENDING_REVIEW')
                      ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        label: const Text('Reject'),
                      ),
                    if (verificationStatus == 'VERIFIED')
                      ElevatedButton.icon(
                        onPressed: onSuspend,
                        icon: Icon(
                          accountStatus == 'ACTIVE'
                              ? Icons.block
                              : Icons.check_circle,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accountStatus == 'ACTIVE'
                              ? Colors.orange
                              : Colors.green,
                        ),
                        label: Text(
                          accountStatus == 'ACTIVE'
                              ? 'Suspend'
                              : 'Activate',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _getAssignedPatientCount(WidgetRef ref, String caregiverId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final links = await client
          .from('caregiver_patient_mapping')
          .select()
          .eq('caregiver_id', caregiverId);
      return links.length;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildStatusBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: MedicalTheme.lightSlate,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: MedicalTheme.lightSlate,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
