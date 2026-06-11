import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/verification_service.dart';

class DoctorCredentialsUploadScreen extends ConsumerStatefulWidget {
  const DoctorCredentialsUploadScreen({super.key});

  @override
  ConsumerState<DoctorCredentialsUploadScreen> createState() =>
      _DoctorCredentialsUploadScreenState();
}

class _DoctorCredentialsUploadScreenState
    extends ConsumerState<DoctorCredentialsUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _licenseStateController = TextEditingController();
  final _medicalSchoolController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _specializationController = TextEditingController();
  bool _boardCertified = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _licenseStateController.dispose();
    _medicalSchoolController.dispose();
    _yearsExperienceController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        _showError('Not authenticated');
        return;
      }

      final yearsExp = int.tryParse(_yearsExperienceController.text) ?? 0;

      await VerificationService(ref.read(supabaseClientProvider))
          .submitDoctorCredentials(
        userId: session.user.id,
        licenseNumber: _licenseNumberController.text.trim(),
        licenseState: _licenseStateController.text.trim(),
        medicalSchool: _medicalSchoolController.text.trim(),
        yearsExperience: yearsExp,
        specialization: _specializationController.text.trim(),
        boardCertified: _boardCertified,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credentials submitted for verification'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(myVerificationStatusProvider);
        ref.invalidate(myDoctorCredentialsProvider);
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
        title: const Text('Verify Medical Credentials'),
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
                    'Please provide your medical credentials and license information. Our admin team will verify the details before activating your account.',
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
                  _buildFormField(
                    controller: _licenseNumberController,
                    label: 'Medical License Number',
                    hint: 'e.g., MD123456',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'License number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _licenseStateController,
                    label: 'License State/Country',
                    hint: 'e.g., California, UK',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'License state/country is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _medicalSchoolController,
                    label: 'Medical School',
                    hint: 'e.g., Harvard Medical School',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Medical school is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _yearsExperienceController,
                    label: 'Years of Experience',
                    hint: 'e.g., 10',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Years of experience is required';
                      }
                      if (int.tryParse(value!) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _specializationController,
                    label: 'Specialization',
                    hint: 'e.g., Neurology, Geriatrics',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Specialization is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCheckbox(
                    value: _boardCertified,
                    label: 'Board Certified',
                    onChanged: (value) {
                      setState(() => _boardCertified = value ?? false);
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitCredentials,
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: MedicalTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: MedicalTheme.lightSlate),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: MedicalTheme.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: MedicalTheme.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: MedicalTheme.primaryTeal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
          style: const TextStyle(color: MedicalTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: MedicalTheme.primaryTeal,
        ),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MedicalTheme.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
