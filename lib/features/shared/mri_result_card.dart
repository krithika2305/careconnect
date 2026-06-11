import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MriResultCard extends StatelessWidget {
  final String prediction;
  final double confidence;
  final Map<String, double> allClasses;
  final DateTime analyzedAt;

  const MriResultCard({
    super.key,
    required this.prediction,
    required this.confidence,
    required this.allClasses,
    required this.analyzedAt,
  });

  @override
  Widget build(BuildContext context) {
    // Sort classes by confidence descending
    final sortedEntries = allClasses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Determine color based on prediction
    Color _getPredictionColor() {
      final lower = prediction.toLowerCase();
      if (lower.contains('non')) return CareTheme.success;
      if (lower.contains('very mild') || lower.contains('mild')) return CareTheme.warning;
      if (lower.contains('moderate')) return CareTheme.error;
      return CareTheme.accentPink;
    }

    // Simple interpretation
    String _getInterpretation() {
      if (confidence > 80) return 'High confidence diagnosis';
      if (confidence > 60) return 'Moderate confidence diagnosis';
      return 'Low confidence – consider clinical review';
    }

    final themeColor = _getPredictionColor();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CareTheme.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: themeColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'MRI Analysis Report',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: CareTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Prediction badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Prediction: $prediction (${confidence.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Probability bars for all classes
          ...sortedEntries.map((entry) {
            final isPrimary = entry.key == prediction;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                            color: isPrimary ? CareTheme.textPrimary : CareTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                          color: isPrimary ? CareTheme.textPrimary : CareTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (entry.value / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: isPrimary ? themeColor : CareTheme.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Interpretation and timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: CareTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getInterpretation(),
                  style: TextStyle(
                    fontSize: 12,
                    color: CareTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: CareTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                _formatTime(analyzedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: CareTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final localDt = dt.toLocal();
    final day = localDt.day.toString().padLeft(2, '0');
    final month = localDt.month.toString().padLeft(2, '0');
    final year = localDt.year;
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
