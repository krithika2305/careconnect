import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/verification_service.dart';

class CaregiverVerificationScreen extends ConsumerStatefulWidget {
  const CaregiverVerificationScreen({super.key});

  @override
  ConsumerState<CaregiverVerificationScreen> createState() =>
      _CaregiverVerificationScreenState();
}

class _CaregiverVerificationScreenState
    extends ConsumerState<CaregiverVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _backgroundController = TextEditingController();
  bool _trainingCertificate = false;
  String _backgroundCheckStatus = 'pending';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        _showError('Not authenticated');
        return;
      }

      await VerificationService(ref.read(supabaseClientProvider))
          .submitCaregiverVerification(
        userId: session.user.id,
        professionalBackground: _backgroundController.text.trim(),
        trainingCertificate: _trainingCertificate,
        backgroundCheckStatus: _backgroundCheckStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification information submitted'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(myVerificationStatusProvider);
        ref.invalidate(myCaregiverVerificationProvider);
        ref.invalidate(myVerificationRequestProvider);
        context.go('/pending-verification');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: const Text('Verify Care Partner Account'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MedicalTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MedicalTheme.accentBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: MedicalTheme.accentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Complete Your Verification',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tell us about your background in caregiving. Our admin team will review your information to verify your account.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MedicalTheme.lightSlate,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLabel('Professional Background'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _backgroundController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText:
                          'Tell us about your experience in caregiving (e.g., healthcare background, certifications, previous caregiving roles, family relationships)',
                      hintStyle: const TextStyle(color: MedicalTheme.lightSlate),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: MedicalTheme.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: MedicalTheme.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: MedicalTheme.primaryTeal, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please provide your professional background';
                      }
                      if (value!.length < 20) {
                        return 'Please provide more details (at least 20 characters)';
                      }
                      return null;
                    },
                    style: const TextStyle(color: MedicalTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Training & Certifications'),
                  const SizedBox(height: 12),
                  _buildCheckbox(
                    value: _trainingCertificate,
                    label:
                        'I have formal training or certification in caregiving (CNA, nursing, etc.)',
                    onChanged: (value) {
                      setState(() => _trainingCertificate = value ?? false);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Background Check Status'),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: _backgroundCheckStatus,
                    items: [
                      ('pending', 'Not Started - I will initiate background check'),
                      ('clear', 'Already Completed - Background check clear'),
                      ('failed', 'Already Completed - Failed background check'),
                    ],
                    onChanged: (value) {
                      setState(() => _backgroundCheckStatus = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MedicalTheme.accentGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MedicalTheme.accentGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: MedicalTheme.accentGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Background Check Info',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A background check is required to provide care coordination services. If you haven\'t completed one, you can initiate it during the verification process.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MedicalTheme.lightSlate,
                                    height: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MedicalTheme.primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit for Verification',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Verification typically takes 1-2 business days',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedicalTheme.lightSlate,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: MedicalTheme.textPrimary,
          ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: MedicalTheme.primaryTeal,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MedicalTheme.textPrimary,
                    height: 1.4,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MedicalTheme.lightBorder),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item.$1,
                child: Text(item.$2),
              ),
            )
            .toList(),
        onChanged: onChanged,
        style: const TextStyle(color: MedicalTheme.textPrimary),
      ),
    );
  }
}
