import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'doctor_clinical_panel.dart';

/// Full-screen clinical tools — keeps dashboard scroll reliable.
class DoctorClinicalScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const DoctorClinicalScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MedicalTheme.lightBg,
      appBar: AppBar(
        title: Text('Clinical — $patientName'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const ClampingScrollPhysics(),
        child: DoctorClinicalPanel(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }
}
