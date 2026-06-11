import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MedicationReminderCard extends StatelessWidget {
  final String title;
  final String time;
  final String? pillImageUrl;
  final String? dosage;
  final String? instructions;
  final String? type;
  final bool done;
  final bool loading;
  final VoidCallback? onMarkDone;
  final VoidCallback? onDelete;
  final bool darkStyle;

  const MedicationReminderCard({
    super.key,
    required this.title,
    required this.time,
    this.pillImageUrl,
    this.dosage,
    this.instructions,
    this.type,
    this.done = false,
    this.loading = false,
    this.onMarkDone,
    this.onDelete,
    this.darkStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkStyle ? Colors.white : Colors.black87;
    final subtitleColor = darkStyle ? Colors.white70 : Colors.black54;
    final cardColor = darkStyle ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: darkStyle
            ? []
            : [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: pillImageUrl != null && pillImageUrl!.isNotEmpty
                  ? Image.network(pillImageUrl!, width: 48, height: 48, fit: BoxFit.cover)
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: MedicalTheme.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.medication, color: MedicalTheme.primaryTeal, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(fontSize: 12, color: subtitleColor)),
                  if (dosage != null && dosage!.isNotEmpty)
                    Text('Dosage: $dosage', style: TextStyle(fontSize: 12, color: subtitleColor)),
                  if (instructions != null && instructions!.isNotEmpty)
                    Text(instructions!, style: TextStyle(fontSize: 11, color: subtitleColor)),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 22),
                onPressed: loading ? null : onDelete,
                color: Colors.red[400],
              ),
            if (onMarkDone != null)
              done
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MedicalTheme.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Done', style: TextStyle(color: MedicalTheme.accentGreen, fontSize: 12)),
                    )
                  : TextButton(
                      onPressed: loading ? null : onMarkDone,
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Take', style: TextStyle(color: MedicalTheme.primaryTeal)),
                    ),
          ],
        ),
      ),
    );
  }
}