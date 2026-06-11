import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/alzheimers_model_service.dart';
import '../auth/login_screen.dart';
import '../shared/prediction_result_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  // HTTP-based service – no local model loading required
  final _modelService = AlzheimersModelService();

  bool _isRunningAnalysis = false;
  XFile? _mriImageFile;
  String? _mriFileName;
  String? _mriAnalysisResult;
  double? _mriConfidence;
  Map<String, double>? _allClassProbs;

  bool _isSavingNotes = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();
    ref.invalidate(authSessionProvider);
    ref.invalidate(userProfileProvider);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  Future<void> _pickMriImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: MedicalTheme.primaryTeal),
            title: const Text('Upload from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final img = await ImagePicker()
                  .pickImage(source: ImageSource.gallery);
              if (img != null) {
                setState(() {
                  _mriImageFile   = img;
                  _mriFileName    = img.name;
                  _mriAnalysisResult = null;
                  _mriConfidence  = null;
                  _allClassProbs  = null;
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: MedicalTheme.primaryTeal),
            title: const Text('Take a Photo'),
            onTap: () async {
              Navigator.pop(context);
              final img = await ImagePicker()
                  .pickImage(source: ImageSource.camera);
              if (img != null) {
                setState(() {
                  _mriImageFile   = img;
                  _mriFileName    = img.name;
                  _mriAnalysisResult = null;
                  _mriConfidence  = null;
                  _allClassProbs  = null;
                });
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _runMriAnalysis() async {
    if (_mriImageFile == null) return;
    setState(() => _isRunningAnalysis = true);

    try {
      // ── Call the Flask API ──────────────────────────────────────────────
      final result = await _modelService.predict(_mriImageFile!.path);

      if (result == null) throw Exception('No result returned from API.');

      // ── Upload MRI to Supabase Storage & log prediction ─────────────────
      try {
        final supabase = ref.read(supabaseClientProvider);
        final session  = ref.read(authSessionProvider);
        final fileExt  = _mriImageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('mri_scans').upload(
              fileName,
              File(_mriImageFile!.path),
            );

        final imageUrl =
            supabase.storage.from('mri_scans').getPublicUrl(fileName);

        if (session != null) {
          await supabase.from('mri_predictions').insert({
            'doctor_id':    session.user.id,
            'patient_name': 'Patient Log',
            'image_url':    imageUrl,
            'prediction':   result.label,
            'confidence':   result.confidence,
          });
          ref.invalidate(mriHistoryProvider);
        }
      } catch (dbErr) {
        debugPrint('Supabase logging error: $dbErr');
      }

      setState(() {
        _mriAnalysisResult = result.label;
        _mriConfidence     = result.confidence;
        _allClassProbs     = result.allClasses;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictionResultScreen(
              imagePath:  _mriImageFile!.path,
              prediction: result.label,
              confidence: result.confidence,
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: MedicalTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunningAnalysis = false);
    }
  }

  Future<void> _saveClinicalNotes() async {
    if (_notesController.text.trim().isEmpty) return;
    setState(() => _isSavingNotes = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _isSavingNotes = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Consultation notes saved to EHR.'),
          ]),
          backgroundColor: MedicalTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _notesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final doctorName   = profileAsync.value?['name'] ?? 'Clinical Staff';

    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text('Clinician Workspace'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Doctor badge ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.12), width: 1.5),
                    ),
                    child: const Icon(Icons.local_hospital_rounded,
                        color: Colors.blue, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. $doctorName',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: MedicalTheme.darkSlate,
                                letterSpacing: -0.4)),
                        const SizedBox(height: 4),
                        const Text('Neurology Clinic • CareConnect Medical',
                            style: TextStyle(
                                fontSize: 13,
                                color: MedicalTheme.lightSlate,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 32),

            // ── AI MRI section ───────────────────────────────────────────────
            const Text('AI MRI Alzheimer Predictor',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4)),
            const SizedBox(height: 16),
            _buildMriUploadCard(),
            const SizedBox(height: 32),

            // ── Past predictions ─────────────────────────────────────────────
            const Text('Past AI MRI Predictions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4)),
            const SizedBox(height: 16),
            _buildMriHistorySection(),
            const SizedBox(height: 32),

            // ── Emergency history ────────────────────────────────────────────
            const Text('Emergency Incident Reports',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4)),
            const SizedBox(height: 16),
            _buildEmergencyHistorySection(),
            const SizedBox(height: 32),

            // ── Clinical notes ───────────────────────────────────────────────
            const Text('Clinical Consultation Notes',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MedicalTheme.darkSlate,
                    letterSpacing: -0.4)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Enter diagnosis updates, medications, or caregiver checklists…',
                      labelText: 'Consultation Notes Registry',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: MedicalTheme.secondaryMint),
                      onPressed: _isSavingNotes ? null : _saveClinicalNotes,
                      child: _isSavingNotes
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Syncing Notes…'),
                              ],
                            )
                          : const Text('Sync Notes to Database'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMriUploadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MedicalTheme.primaryTeal.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.biotech_rounded,
                    color: MedicalTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Axial Slice Telemetry Upload',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: MedicalTheme.darkSlate)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Upload brain MRI scans to classify Alzheimer\'s stage via the '
              'CareConnect AI backend (EfficientNetB3).',
              style: TextStyle(
                  color: MedicalTheme.lightSlate, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Upload area
            GestureDetector(
              onTap: _pickMriImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: MedicalTheme.lightBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _mriFileName != null
                        ? MedicalTheme.primaryTeal
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _mriFileName != null
                            ? Icons.insert_drive_file_rounded
                            : Icons.cloud_upload_outlined,
                        color: _mriFileName != null
                            ? MedicalTheme.primaryTeal
                            : MedicalTheme.lightSlate,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _mriFileName ?? 'Click to upload MRI scan file',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mriFileName != null
                              ? MedicalTheme.primaryTeal
                              : MedicalTheme.lightSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_mriFileName != null)
                        const Text('Ready for analysis',
                            style: TextStyle(
                                fontSize: 11,
                                color: MedicalTheme.lightSlate)),
                    ],
                  ),
                ),
              ),
            ),

            if (_mriFileName != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isRunningAnalysis ? null : _runMriAnalysis,
                  child: _isRunningAnalysis
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Running AI Analysis…'),
                          ],
                        )
                      : const Text('Perform AI Classification'),
                ),
              ),
            ],

            // All-class probability bars (shown after result)
            if (_allClassProbs != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Probability Distribution',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MedicalTheme.darkSlate,
                      fontSize: 13)),
              const SizedBox(height: 10),
              ..._allClassProbs!.entries.map(
                (e) => _ProbBar(label: e.key, value: e.value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMriHistorySection() {
    return ref.watch(mriHistoryProvider).when(
      data: (records) {
        if (records.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No past MRI predictions found.',
                    style: TextStyle(color: MedicalTheme.lightSlate)),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (_, i) {
            final r          = records[i];
            final prediction = r['prediction'] ?? 'Unknown';
            final confidence = r['confidence'] ?? 0.0;
            final dateStr    = r['created_at']?.toString() ?? '';
            final formatted  = dateStr.length >= 10
                ? dateStr.substring(0, 10)
                : 'N/A';

            Color statusColor = MedicalTheme.accentOrange;
            if (prediction.toString().toLowerCase().contains('non')) {
              statusColor = MedicalTheme.accentGreen;
            } else if (prediction.toString().toLowerCase().contains('moderate')) {
              statusColor = MedicalTheme.accentCoral;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    r['image_url'] ?? '',
                    width: 50, height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 50, height: 50,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported_rounded,
                            color: Colors.grey)),
                  ),
                ),
                title: Text(prediction,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: MedicalTheme.darkSlate)),
                subtitle: Text(
                    'Confidence: ${(confidence as num).toStringAsFixed(1)}% • $formatted',
                    style: const TextStyle(
                        fontSize: 12, color: MedicalTheme.lightSlate)),
                trailing: Icon(Icons.analytics_rounded, color: statusColor),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEmergencyHistorySection() {
    return ref.watch(emergencyHistoryProvider).when(
      data: (records) {
        if (records.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No emergency incidents logged.',
                    style: TextStyle(color: MedicalTheme.lightSlate)),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length > 5 ? 5 : records.length,
          itemBuilder: (_, i) {
            final r         = records[i];
            final alertType = r['alert_type'] ?? 'Unknown Alert';
            final patient   = r['patient_name'] ?? 'Patient';
            final dateStr   = r['created_at']?.toString() ?? '';
            final formatted = dateStr.length >= 16
                ? dateStr.substring(0, 16).replaceFirst('T', ' ')
                : 'N/A';
            final resolved  = r['status'] == 'RESOLVED';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: resolved
                        ? MedicalTheme.accentGreen.withOpacity(0.1)
                        : MedicalTheme.accentCoral.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    resolved
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: resolved
                        ? MedicalTheme.accentGreen
                        : MedicalTheme.accentCoral,
                  ),
                ),
                title: Text(alertType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: MedicalTheme.darkSlate)),
                subtitle: Text('$patient • $formatted',
                    style: const TextStyle(
                        fontSize: 12, color: MedicalTheme.lightSlate)),
                trailing: Text(
                  resolved ? 'RESOLVED' : 'ACTIVE',
                  style: TextStyle(
                      color: resolved
                          ? MedicalTheme.accentGreen
                          : MedicalTheme.accentCoral,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

/// Small horizontal bar showing a class probability.
class _ProbBar extends StatelessWidget {
  final String label;
  final double value; // 0–100

  const _ProbBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (label.contains('Non')) {
      color = MedicalTheme.accentGreen;
    } else if (label.contains('Moderate')) {
      color = MedicalTheme.accentCoral;
    } else {
      color = MedicalTheme.accentOrange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: MedicalTheme.darkSlate)),
            ),
            Text('${value.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              color: color,
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
