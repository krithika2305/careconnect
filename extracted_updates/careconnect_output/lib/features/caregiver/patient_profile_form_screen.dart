import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

/// Caregiver fills out the patient's profile details.
/// Can be reached from the CaregiverDashboard.
class PatientProfileFormScreen extends ConsumerStatefulWidget {
  /// The patient's auth user ID this caregiver manages.
  final String patientId;

  const PatientProfileFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientProfileFormScreen> createState() =>
      _PatientProfileFormScreenState();
}

class _PatientProfileFormScreenState
    extends ConsumerState<PatientProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditing = false;

  // Controllers
  final _nameCtrl          = TextEditingController();
  final _dobCtrl           = TextEditingController();
  final _addressCtrl       = TextEditingController();
  final _ecNameCtrl        = TextEditingController();
  final _ecPhoneCtrl       = TextEditingController();
  final _allergiesCtrl     = TextEditingController();
  final _medicationsCtrl   = TextEditingController();
  final _medHistoryCtrl    = TextEditingController();
  final _personalNotesCtrl = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodType;
  DateTime? _selectedDob;

  static const _genders     = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _bloodTypes  = ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−', 'Unknown'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final profile =
        await ref.read(patientProfileProvider(widget.patientId).future);
    if (profile != null && mounted) {
      setState(() {
        _isEditing = true;
        _nameCtrl.text          = profile['full_name']               ?? '';
        _dobCtrl.text           = profile['date_of_birth']           ?? '';
        _selectedGender         = profile['gender'];
        _selectedBloodType      = profile['blood_type'];
        _addressCtrl.text       = profile['address']                 ?? '';
        _ecNameCtrl.text        = profile['emergency_contact_name']  ?? '';
        _ecPhoneCtrl.text       = profile['emergency_contact_phone'] ?? '';
        _allergiesCtrl.text     = profile['known_allergies']         ?? '';
        _medicationsCtrl.text   = profile['current_medications']     ?? '';
        _medHistoryCtrl.text    = profile['medical_history']         ?? '';
        _personalNotesCtrl.text = profile['personal_notes']          ?? '';
      });
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1950),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final client  = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider);

    final payload = {
      'patient_id':               widget.patientId,
      'caregiver_id':             session!.user.id,
      'full_name':                _nameCtrl.text.trim(),
      'date_of_birth':            _dobCtrl.text.trim(),
      'gender':                   _selectedGender,
      'blood_type':               _selectedBloodType,
      'address':                  _addressCtrl.text.trim(),
      'emergency_contact_name':   _ecNameCtrl.text.trim(),
      'emergency_contact_phone':  _ecPhoneCtrl.text.trim(),
      'known_allergies':          _allergiesCtrl.text.trim(),
      'current_medications':      _medicationsCtrl.text.trim(),
      'medical_history':          _medHistoryCtrl.text.trim(),
      'personal_notes':           _personalNotesCtrl.text.trim(),
      'updated_at':               DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (_isEditing) {
        await client
            .from('patient_profiles')
            .update(payload)
            .eq('patient_id', widget.patientId);
      } else {
        await client.from('patient_profiles').insert(payload);
      }

      ref.invalidate(patientProfileProvider(widget.patientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient profile saved successfully.'),
            backgroundColor: MedicalTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: MedicalTheme.accentCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _dobCtrl, _addressCtrl, _ecNameCtrl, _ecPhoneCtrl,
      _allergiesCtrl, _medicationsCtrl, _medHistoryCtrl, _personalNotesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Patient Profile' : 'New Patient Profile'),
        backgroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Basic Information'),
              _field(_nameCtrl, 'Full Name', required: true),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDob,
                child: AbsorbPointer(
                  child: _field(_dobCtrl, 'Date of Birth (YYYY-MM-DD)',
                      required: true,
                      suffixIcon: const Icon(Icons.calendar_today_rounded,
                          color: MedicalTheme.primaryTeal)),
                ),
              ),
              const SizedBox(height: 12),
              _dropdown('Gender', _genders, _selectedGender,
                  (v) => setState(() => _selectedGender = v)),
              const SizedBox(height: 12),
              _dropdown('Blood Type', _bloodTypes, _selectedBloodType,
                  (v) => setState(() => _selectedBloodType = v)),
              const SizedBox(height: 12),
              _field(_addressCtrl, 'Home Address', maxLines: 2),

              const SizedBox(height: 24),
              _sectionTitle('Emergency Contact'),
              _field(_ecNameCtrl, 'Contact Name'),
              const SizedBox(height: 12),
              _field(_ecPhoneCtrl, 'Contact Phone',
                  keyboardType: TextInputType.phone),

              const SizedBox(height: 24),
              _sectionTitle('Medical Details'),
              _field(_allergiesCtrl, 'Known Allergies', maxLines: 2),
              const SizedBox(height: 12),
              _field(_medicationsCtrl, 'Current Medications', maxLines: 3),
              const SizedBox(height: 12),
              _field(_medHistoryCtrl, 'Medical History', maxLines: 3),

              const SizedBox(height: 24),
              _sectionTitle('Personal Notes'),
              _field(_personalNotesCtrl,
                  'Preferences, routines, key memories…',
                  maxLines: 4),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Saving…'),
                          ],
                        )
                      : const Text('Save Patient Profile'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MedicalTheme.darkSlate,
                letterSpacing: -0.3)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }

  Widget _dropdown(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
