import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class AdminDoctorsTab extends ConsumerWidget {
  const AdminDoctorsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersAdminProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading doctors: $e')),
      data: (users) {
        final doctors = users
            .where((u) => (u['role'] as String?)?.toLowerCase() == 'doctor')
            .toList();

        if (doctors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_outlined, size: 48, color: MedicalTheme.lightSlate),
                SizedBox(height: 16),
                Text('No doctors found', style: TextStyle(color: MedicalTheme.lightSlate)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            return _DoctorCard(
              doctor: doctor,
              onViewCredentials: () => _showDoctorCredentials(context, ref, doctor),
              onViewPatients: () => _showAssignedPatients(context, ref, doctor),
              onDeactivate: () => _deactivateDoctor(context, ref, doctor),
              onActivate: () => _activateDoctor(context, ref, doctor),
            );
          },
        );
      },
    );
  }

  void _showDoctorCredentials(BuildContext context, WidgetRef ref, Map<String, dynamic> doctor) async {
    final client = ref.read(supabaseClientProvider);
    
    try {
      final credentials = await client
          .from('doctor_credentials')
          .select()
          .eq('user_id', doctor['id'])
          .maybeSingle();

      final request = await client
          .from('user_verification_requests')
          .select()
          .eq('user_id', doctor['id'])
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

      final licenseUrl = credentials?['license_document_path'] ?? submittedDocs['license_document_url'];
      final degreeUrl = submittedDocs['degree_document_url'];
      final govIdUrl = submittedDocs['government_id_url'];
      final boardCertUrl = submittedDocs['board_certification_url'];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${doctor['name']} - Credentials'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Name', doctor['name']),
                _detailRow('Email', doctor['email']),
                _detailRow('Verification Status', doctor['verification_status']?.toString().toUpperCase()),
                _detailRow('Account Status', doctor['account_status']?.toString().toUpperCase()),
                const Divider(height: 32),
                if (credentials != null) ...[
                  _detailRow('License Number', credentials['license_number']),
                  _detailRow('License State', credentials['license_state']),
                  _detailRow('Medical School', credentials['medical_school']),
                  _detailRow('Years of Experience', credentials['years_experience']?.toString()),
                  _detailRow('Specialization', credentials['specialization']),
                  _detailRow('Board Certified', credentials['board_certified'] == true ? 'Yes' : 'No'),
                  _detailRow('Uploaded At', _formatDate(credentials['uploaded_at'])),
                  _detailRow('Verified At', credentials['verified_at'] != null ? _formatDate(credentials['verified_at']) : 'Not verified'),
                ] else ...[
                  const Text('No credentials found', style: TextStyle(color: MedicalTheme.lightSlate)),
                ],
                const Divider(height: 32),
                const Text(
                  'Verification Documents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildDocumentRow(context, 'Medical License', licenseUrl),
                _buildDocumentRow(context, 'Degree Certificate', degreeUrl),
                _buildDocumentRow(context, 'Government ID', govIdUrl),
                _buildDocumentRow(context, 'Board Certification Documents', boardCertUrl),
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
            content: Text('Error loading credentials: $e'),
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

  void _showAssignedPatients(BuildContext context, WidgetRef ref, Map<String, dynamic> doctor) async {
    final client = ref.read(supabaseClientProvider);
    
    try {
      final mappings = await client
          .from('doctor_patient_mapping')
          .select('patient_id, status, assigned_at')
          .eq('doctor_id', doctor['id']);

      if (!context.mounted) return;

      if (mappings.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${doctor['name']} - Assigned Patients'),
            content: const Text('No patients assigned to this doctor'),
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
      print('DOCTOR: ${doctor['id']}');
      print('MAPPINGS: $mappings');

      // Get patient details
      final patientIds =
          mappings.map((m) => m['patient_id'].toString()).toList();
      print('PATIENT IDS: $patientIds');
      
      final patients = await client
          .from('users')
          .select('id, name, email')
          .inFilter('id', patientIds);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${doctor['name']} - Assigned Patients (${patients.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final mapping = mappings.firstWhere((m) => m['patient_id'] == patient['id']);
                return ListTile(
                  title: Text(patient['name'] ?? 'Unknown'),
                  subtitle: Text(patient['email'] ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: mapping['status'] == 'accepted' 
                          ? MedicalTheme.accentGreen.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mapping['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 11,
                        color: mapping['status'] == 'accepted' 
                            ? MedicalTheme.accentGreen
                            : Colors.orange,
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

  void _deactivateDoctor(BuildContext context, WidgetRef ref, Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Doctor'),
        content: Text('Are you sure you want to deactivate ${doctor['name']}\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDoctorStatus(context, ref, doctor['id'], 'SUSPENDED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _activateDoctor(BuildContext context, WidgetRef ref, Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Doctor'),
        content: Text('Are you sure you want to activate ${doctor['name']}\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDoctorStatus(context, ref, doctor['id'], 'ACTIVE');
            },
            style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.accentGreen),
            child: const Text('Activate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDoctorStatus(
    BuildContext context,
    WidgetRef ref,
    String doctorId,
    String status,
  ) async {
    try {
      final client = ref.read(supabaseClientProvider);

      Map<String, dynamic> updateData = {
        'account_status': status,
      };

      // Admin approval
      if (status == 'ACTIVE') {
        updateData['verification_status'] = 'VERIFIED';
        updateData['verification_completed_at'] =
            DateTime.now().toIso8601String();
      }

      // Suspension
      if (status == 'SUSPENDED') {
        updateData['account_status'] = 'SUSPENDED';
      }

      await client
          .from('users')
          .update(updateData)
          .eq('id', doctorId);

      ref.invalidate(allUsersAdminProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'ACTIVE'
                  ? 'Doctor approved successfully'
                  : 'Doctor suspended successfully',
            ),
            backgroundColor: status == 'ACTIVE'
                ? MedicalTheme.accentGreen
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating doctor status: $e'),
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

class _DoctorCard extends ConsumerWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onViewCredentials;
  final VoidCallback onViewPatients;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;

  const _DoctorCard({
    required this.doctor,
    required this.onViewCredentials,
    required this.onViewPatients,
    required this.onDeactivate,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountStatus = doctor['account_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final verificationStatus = doctor['verification_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    
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
      future: _getAssignedPatientCount(ref, doctor['id']),
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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor['name'] ?? 'Unknown Doctor',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            doctor['email'] ?? '',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusBadge(
                      'Status',
                      accountStatus,
                      statusColor,
                    ),
                    _buildStatusBadge(
                      'Verification',
                      verificationStatus,
                      verificationColor,
                    ),
                    _buildInfoBadge(
                      'Patients',
                      patientCount.toString(),
                      MedicalTheme.primaryTeal,
                    ),
                  ],
),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onViewCredentials,
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('View Credentials'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
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
                    if (verificationStatus != 'VERIFIED')
                      ElevatedButton.icon(
                        onPressed: onActivate,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MedicalTheme.accentGreen,
                        ),
                      ),

                    if (verificationStatus == 'VERIFIED')
                      ElevatedButton.icon(
                        onPressed: onDeactivate,
                        icon: const Icon(Icons.block),
                        label: Text(
                          accountStatus == 'ACTIVE'
                              ? 'Suspend'
                              : 'Activate',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              accountStatus == 'ACTIVE'
                                  ? Colors.orange
                                  : MedicalTheme.accentGreen,
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

  Future<int> _getAssignedPatientCount(WidgetRef ref, String doctorId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final mappings = await client
          .from('doctor_patient_mapping')
          .select()
          .eq('doctor_id', doctorId)
          .eq('status', 'accepted');
      return mappings.length;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildStatusBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: MedicalTheme.lightSlate,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: MedicalTheme.lightSlate,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
